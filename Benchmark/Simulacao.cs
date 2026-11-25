using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Linq;

public static class BenchmarkCdc
{
    const double BaseDt = .0005, Ts = .001, Ganho = 4000;
    const double Ms = 250, Mu = 40, Ks = 16000, Kt = 200000, Peso = (Ms + Mu) * 9.81;
    const double TauV3 = .015, CMin = 600, CMax = 2400;
    const double CorrenteMax = 1.5, TensaoMax = 12, R = 5, L = .02;
    const double Kp = 10, Ki = 2500, VEps = .01;
    static readonly CultureInfo Invariante = CultureInfo.InvariantCulture;
    static readonly double Fuga = 1 / (1 + 2 * Math.PI * .1 * Ts);
    enum Modelo { Passiva, V3, CDC, CDC_Limite }

    struct Estado
    {
        public double Zs, Vs, Zu, Vu, I, Abertura;
        public static Estado operator +(Estado a, Estado b) => new Estado {
            Zs = a.Zs + b.Zs, Vs = a.Vs + b.Vs, Zu = a.Zu + b.Zu, Vu = a.Vu + b.Vu,
            I = a.I + b.I, Abertura = a.Abertura + b.Abertura
        };
        public static Estado operator *(double k, Estado a) => new Estado {
            Zs = k*a.Zs, Vs = k*a.Vs, Zu = k*a.Zu, Vu = k*a.Vu, I = k*a.I, Abertura = k*a.Abertura
        };
    }

    sealed class Pista
    {
        public string Nome;
        public int Semente;
        public double[] Altura;
        public double Inicio => Semente == 0 ? 1 : 5;
    }

    sealed class Metricas
    {
        public double SomaA, SomaN, PesoRms, PicoA, Curso, TempoSemContato, MinN = double.PositiveInfinity;
        public double TrabalhoPista, Dissipacao, EnergiaFinal, MaxVr, MinPotencia, PicoForca;
        public int ForaMapa;
        public double RmsA => Math.Sqrt(SomaA / PesoRms);
        public double RmsN => Math.Sqrt(SomaN / PesoRms);
        public double ErroEnergia => Math.Abs(EnergiaFinal - TrabalhoPista + Dissipacao) /
            Math.Max(1, Math.Abs(TrabalhoPista) + Dissipacao);
    }

    static double Limitar(double x, double a, double b) => Math.Min(b, Math.Max(a, x));

    // Ding et al. (2017), Figura 4 e Tabela 1. Extensões lineares fora da bancada
    // mantêm os segmentos externos. A campanha registra se as utiliza.
    static (double Macio, double Firme) LimitesCdc(double v, bool limitarVelocidade = false)
    {
        if (limitarVelocidade) v=Limitar(v,-1.5,1.5);
        if (v >= 0)
            return (Math.Min(3181*v, 587*v + 337),
                    Math.Min(25154*v, Math.Min(4447*v + 1077, 1473*v + 1850)));
        return (381*v, Math.Max(6592*v, Math.Max(1409*v - 674, 351*v - 1489)));
    }

    static double Forca(Modelo modelo, Estado x)
    {
        double v = x.Vs - x.Vu;
        if (modelo == Modelo.Passiva) return 1500*v;
        if (modelo == Modelo.V3) return (CMin + (CMax-CMin)*x.Abertura)*v;
        var limites = LimitesCdc(v,modelo==Modelo.CDC_Limite);
        return limites.Macio + x.Abertura * (limites.Firme-limites.Macio);
    }

    static double Comando(Modelo modelo, double vs, double vr)
    {
        double produto = vs * vr;
        if (produto <= 0) return 0;
        double cPedido = Ganho * produto / (vr*vr + VEps*VEps);
        if (modelo == Modelo.V3) return Limitar((cPedido-CMin)/(CMax-CMin), 0, 1);
        var limites = LimitesCdc(vr,modelo==Modelo.CDC_Limite);
        return Limitar((cPedido*vr-limites.Macio)/(limites.Firme-limites.Macio), 0, 1);
    }

    static double Normal(Estado x, double pista, bool unilateral)
    {
        double n = Peso + Kt * (pista - x.Zu);
        return unilateral ? Math.Max(0, n) : n;
    }

    static Estado Derivada(Estado x, double pista, double tensao, Modelo modelo, bool unilateral, double tau)
    {
        double fs = Ks*(x.Zs-x.Zu) + Forca(modelo, x);
        return new Estado {
            Zs=x.Vs, Vs=-fs/Ms, Zu=x.Vu, Vu=(fs + Normal(x,pista,unilateral) - Peso)/Mu,
            I=(tensao-R*x.I)/L, Abertura=(Limitar(x.I/CorrenteMax,0,1)-x.Abertura)/tau
        };
    }

    static double Energia(Estado x, double pista, bool unilateral)
    {
        double delta = pista-x.Zu, curso = x.Zs-x.Zu;
        double pneu = .5*Kt*delta*delta;
        if (unilateral && delta < -Peso/Kt)
            pneu = -Peso*delta - .5*Peso*Peso/Kt;
        return .5*Ms*x.Vs*x.Vs + .5*Mu*x.Vu*x.Vu + .5*Ks*curso*curso + pneu;
    }

    static Metricas Simular(Pista pista, Modelo modelo, int subdivisoes, bool unilateral, double tau,
        TextWriter sinais = null)
    {
        double dt = BaseDt/subdivisoes;
        int total = (pista.Altura.Length-1)*subdivisoes;
        int periodo = (int)Math.Round(Ts/dt), inicio = (int)Math.Round(pista.Inicio/dt);
        var m = new Metricas();
        var x = new Estado { I=.75, Abertura=.5 };
        double vs=0, vu=0, integral=3.75, erroAnterior=0, tensao=0, cargaAnterior=0, potAnterior=0;
        bool contatoAnterior = true;

        for (int k=0; k<=total; k++)
        {
            int indice = k/subdivisoes;
            double w = pista.Altura[indice];
            double aumento = 0;
            if (k < total) aumento = (pista.Altura[indice+1]-w)/subdivisoes;
            w += (k%subdivisoes)*aumento;
            Estado k1 = Derivada(x,w,tensao,modelo,unilateral,tau);
            if (modelo != Modelo.Passiva && k%periodo == 0)
            {
                vs = Fuga*(vs+Ts*k1.Vs);
                vu = Fuga*(vu+Ts*k1.Vu);
                double erro = CorrenteMax*Comando(modelo,vs,vs-vu)-x.I;
                double incremento = k == 0 ? 0 : .5*Ki*Ts*(erro+erroAnterior);
                double comando = Kp*erro+integral+incremento;
                if (!((comando>TensaoMax && erro>0) || (comando<0 && erro<0)))
                    integral += incremento;
                tensao = Limitar(Kp*erro+integral,0,TensaoMax);
                erroAnterior = erro;
                k1 = Derivada(x,w,tensao,modelo,unilateral,tau);
            }

            double normal=Normal(x,w,unilateral), carga=normal-Peso, vr=x.Vs-x.Vu;
            double forca=Forca(modelo,x), potencia=forca*vr;
            if (sinais != null && k%periodo == 0)
                sinais.WriteLine(Csv(k*dt,w,x.Zs,x.Zu,k1.Vs,normal,forca));
            bool contato = normal > 0;
            m.MinN=Math.Min(m.MinN,normal);
            m.MinPotencia=Math.Min(m.MinPotencia,potencia);
            m.MaxVr=Math.Max(m.MaxVr,Math.Abs(vr));
            m.Curso=Math.Max(m.Curso,Math.Abs(x.Zs-x.Zu));
            m.PicoForca=Math.Max(m.PicoForca,Math.Abs(forca));
            if ((modelo==Modelo.CDC || modelo==Modelo.CDC_Limite) && Math.Abs(vr)>1.5) m.ForaMapa++;
            if (k>=inicio)
            {
                double peso = (k==inicio || k==total) ? .5 : 1;
                m.PesoRms+=peso;
                m.SomaA+=peso*k1.Vs*k1.Vs;
                m.SomaN+=peso*carga*carga;
                m.PicoA=Math.Max(m.PicoA,Math.Abs(k1.Vs));
            }
            if (k>0)
            {
                double wAnterior = k%subdivisoes==0
                    ? w-(w-pista.Altura[indice-1])/subdivisoes : w-aumento;
                m.TrabalhoPista += .5*(carga+cargaAnterior)*(w-wAnterior);
                m.Dissipacao += .5*(potencia+potAnterior)*dt;
                m.TempoSemContato += .5*((contato?0:1)+(contatoAnterior?0:1))*dt;
            }
            cargaAnterior=carga;
            potAnterior=potencia;
            contatoAnterior=contato;
            if (k==total)
            {
                m.EnergiaFinal=Energia(x,w,unilateral);
                break;
            }
            double meio=w+.5*aumento, fim=w+aumento;
            var k2=Derivada(x+.5*dt*k1,meio,tensao,modelo,unilateral,tau);
            var k3=Derivada(x+.5*dt*k2,meio,tensao,modelo,unilateral,tau);
            var k4=Derivada(x+dt*k3,fim,tensao,modelo,unilateral,tau);
            x+=(dt/6)*(k1+2*k2+2*k3+k4);
        }
        return m;
    }

    static string Csv(params object[] campos) => string.Join(",", campos.Select(c =>
        c is IFormattable f ? f.ToString(null, Invariante) : c.ToString()));
    static void Exigir(bool ok, string descricao)
    {
        if (!ok) throw new InvalidOperationException(descricao);
    }
    static double Rel(double a, double b) => Math.Abs(a/b-1);

    public static void Executar(string fonte, string destino)
    {
        var limitesPos=LimitesCdc(.5);
        var limitesNeg=LimitesCdc(-.5);
        Exigir(limitesPos==(630.5,2586.5) && limitesNeg==(-190.5,-1378.5),
            "O envelope do CDC não reproduziu os pontos da Tabela 1.");
        for (int j=-1500; j<=1500; j++)
        {
            double v=j/1000.0;
            var limites=LimitesCdc(v);
            Exigir(limites.Macio*v>=0 && limites.Firme*v>=limites.Macio*v,
                "O envelope CDC viola a dissipação em um ponto da bancada.");
        }
        var plano = new Pista { Nome="plano", Semente=0, Altura=new double[4001] };
        foreach (Modelo modelo in Enum.GetValues(typeof(Modelo)))
        {
            var repouso=Simular(plano,modelo,1,true,TauV3);
            Exigir(repouso.RmsA==0 && repouso.RmsN==0 && repouso.MinN==Peso, "Equilíbrio em pista plana.");
        }
        var verificacao=new List<string> {
            "cenario,semente,modelo,tau_ms,desvio_rms_aceleracao,desvio_rms_carga,delta_contato_s,erro_balanco_energia,min_potencia_dissipada_W,fora_mapa_amostras"
        };
        var resultados=new List<string> {
            "cenario,semente,modelo,tau_ms,dt_ms,rms_aceleracao_m_s2,rms_carga_N,pico_aceleracao_m_s2,curso_max_cm,min_normal_N,sem_contato_ms,forca_amortecedor_pico_N,max_vel_rel_m_s"
        };
        var reproducao=new List<string> {
            "cenario,semente,modelo,rms_aceleracao_original,rms_aceleracao_reproduzido,rms_carga_original,rms_carga_reproduzido,desvio_rms_aceleracao,desvio_rms_carga"
        };
        var referencias=File.ReadLines(Path.Combine(fonte,"metricas_por_ensaio.csv")).Skip(1)
            .ToDictionary(l => {var c=l.Split(','); return c[0]=="lombada" ? 0 : int.Parse(c[1],Invariante);},
                          l => l.Split(','));
        for (int s=0; s<=5; s++)
        {
            string nome=s==0 ? "lombada" : "iso8608";
            string arquivo=s==0 ? "sinais_lombada.csv" : $"sinais_iso8608_semente{s}.csv";
            var pista = new Pista {Nome=nome, Semente=s, Altura=LerPista(fonte,arquivo)
                .Skip(1).Select((l,k) => {
                    string[] c=l.Split(',');
                    Exigir(Math.Abs(Ler(c[0])-k*BaseDt)<1e-9,"A malha de tempo da pista mudou.");
                    return Ler(c[1]);
                }).ToArray()};
            Exigir(pista.Altura.Length==(s==0 ? 16001 : 60001) && pista.Altura[0]==0,
                "A duração ou a altura inicial da pista mudou.");
            foreach (Modelo modelo in new[]{Modelo.Passiva,Modelo.V3})
            {
                var bilateral=Simular(pista,modelo,1,false,TauV3);
                var refCsv=referencias[s];
                int col=modelo==Modelo.Passiva?0:1;
                double a=Ler(refCsv[5+col]), n=Ler(refCsv[10+col]);
                reproducao.Add(Csv(nome,s,modelo,a,bilateral.RmsA,n,bilateral.RmsN,
                    Rel(bilateral.RmsA,a),Rel(bilateral.RmsN,n)));
            }
            foreach (Modelo modelo in Enum.GetValues(typeof(Modelo)))
            foreach (double tau in modelo==Modelo.CDC || modelo==Modelo.CDC_Limite
                ? new[]{.0075,.015,.030} : new[]{TauV3})
            {
                var nominal=Simular(pista,modelo,2,true,tau);
                using var sinais = AbrirSinais(destino,pista,modelo,tau);
                var fino=Simular(pista,modelo,4,true,tau,sinais);
                VerificarConvergencia(pista,modelo,tau,nominal,fino,verificacao);
                resultados.Add(Csv(nome,s,modelo,tau*1000,.125,fino.RmsA,fino.RmsN,fino.PicoA,
                    100*fino.Curso,fino.MinN,1000*fino.TempoSemContato,fino.PicoForca,fino.MaxVr));
            }
            Console.WriteLine($"Simulações concluídas: {pista.Nome}, semente {s}.");
        }
        File.WriteAllLines(Path.Combine(destino,"metricas.csv"),resultados);
        File.WriteAllLines(Path.Combine(destino,"validacao.csv"),verificacao);
        File.WriteAllLines(Path.Combine(destino,"reproducao_simulink.csv"),reproducao);
        foreach (string linha in reproducao.Skip(1))
        {
            var c=linha.Split(',');
            Exigir(Ler(c[7])<.005 && Ler(c[8])<.005, "Reprodução do Simulink fora de 0,5%: "+linha);
        }
        Console.WriteLine("Validação aprovada: equilíbrio, envelope, reprodução, convergência e balanço de energia.");
    }

    static double Ler(string x) => double.Parse(x, Invariante);

    static IEnumerable<string> LerPista(string fonte, string arquivo)
    {
        string caminho = Path.Combine(fonte,arquivo);
        if (File.Exists(caminho))
        {
            foreach (string linha in File.ReadLines(caminho)) yield return linha;
            yield break;
        }
        using var comprimido = new GZipStream(File.OpenRead(caminho+".gz"),CompressionMode.Decompress);
        using var leitor = new StreamReader(comprimido);
        string linhaCsv;
        while ((linhaCsv=leitor.ReadLine()) != null) yield return linhaCsv;
    }

    static TextWriter AbrirSinais(string destino, Pista pista, Modelo modelo, double tau)
    {
        if ((pista.Semente!=0 && pista.Semente!=5) || tau!=TauV3 ||
            (modelo!=Modelo.V3 && modelo!=Modelo.CDC)) return null;
        string caminho = Path.Combine(destino,$"sinais_{pista.Nome}_{pista.Semente}_{modelo}.csv.gz");
        var resultado = new StreamWriter(new GZipStream(File.Create(caminho),CompressionLevel.Optimal));
        resultado.WriteLine("tempo_s,pista_m,carroceria_m,roda_m,aceleracao_m_s2,normal_N,forca_amortecedor_N");
        return resultado;
    }

    static void VerificarConvergencia(Pista pista, Modelo modelo, double tau, Metricas a, Metricas b,
        List<string> registros)
    {
        double da=Rel(a.RmsA,b.RmsA), dn=Rel(a.RmsN,b.RmsN), dc=Math.Abs(a.TempoSemContato-b.TempoSemContato);
        string caso=$"{pista.Nome}/{pista.Semente}/{modelo}/{tau}";
        Exigir(da<.005 && dn<.005 && dc<.002, "Convergência fora da tolerância: "+caso);
        Exigir(b.MinN>=0 && b.MinPotencia>=-1e-9 && b.ErroEnergia<.005,
            $"Verificações físicas fora da tolerância: {caso}, N={b.MinN}, P={b.MinPotencia}, " +
            $"energia={b.ErroEnergia}, fora do mapa={b.ForaMapa}, max |vr|={b.MaxVr}");
        registros.Add(Csv(pista.Nome,pista.Semente,modelo,tau*1000,da,dn,dc,
            b.ErroEnergia,b.MinPotencia,b.ForaMapa));
    }
}
