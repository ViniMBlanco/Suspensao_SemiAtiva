"""Reprodução numérica da suspensão semiativa com RK4 e ZOH."""
import csv
import ctypes as ct
from functools import lru_cache
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

RAIZ = Path(__file__).resolve().parent
REPO = RAIZ.parent
DT, TS, PESO = .0005, .001, 290*9.81
GANHOS = [600, 900, 1200, 1500, 2000, 2500, 3000, 4000, 6000, 8000]
PASSIVOS = list(range(600, 2401, 200))
SEMENTES = range(1, 6)
COLUNAS = ["tempo_s","pista_m","as_pass","as_semi","carga_pass","carga_semi",
           "curso_pass","curso_semi","c_Ns_m","i_A","u_V","i_ref_A"]

@lru_cache(maxsize=1)
def biblioteca():
    with TemporaryDirectory() as pasta:
        alvo = Path(pasta) / "integrador.so"
        subprocess.run(["cc", "-O3", "-shared", "-fPIC", str(RAIZ / "integrador_v3.c"),
                        "-lm", "-o", str(alvo)], check=True)
        lib = ct.CDLL(str(alvo))
    f64 = np.ctypeslib.ndpointer(dtype=np.float64, flags="C_CONTIGUOUS")
    lib.integrar.argtypes = [ct.c_int, f64, ct.c_double, ct.c_double, ct.c_double,
                             ct.c_double, ct.c_double, f64]
    lib.integrar.restype = None
    return lib

def simular(t, w, ganho, cp=1500, ts=TS, tau=.015):
    dt = float(t[1] - t[0])
    if not np.isclose(ts/dt, round(ts/dt)) or ts < dt:
        raise ValueError("O período de controle deve ser um múltiplo do passo.")
    y = np.empty((len(t),10))
    biblioteca().integrar(len(t), np.ascontiguousarray(w,dtype=float), dt, ts, tau, ganho, cp, y)
    return y

def pista_iso(semente, dt=DT):
    t = np.arange(round(30/dt)+1)*dt
    bordas = np.geomspace(.011, 2.83, 401)
    frequencias = 20*np.sqrt(bordas[1:]*bordas[:-1])
    amplitudes = np.sqrt(2*256e-6*.1**2*(1/bordas[:-1]-1/bordas[1:]))
    fases = 2*np.pi*np.random.RandomState(semente).rand(400)
    w = np.zeros_like(t)
    for a, f, fase in zip(amplitudes, frequencias, fases):
        w += a*np.cos(2*np.pi*f*t+fase)
    return t, w-w[0]

def lombada(dt=DT):
    t = np.arange(round(8/dt)+1)*dt
    fase = (t-1)/.7
    return t, np.where((fase>=0)&(fase<=1), .025*(1-np.cos(2*np.pi*fase)),0)

def metricas(t, w, y, inicio, ramo=1):
    a, carga, curso = y[:,ramo], y[:,ramo+2], y[:,ramo+4]
    sel = t >= inicio
    normal = PESO + carga
    def rms(v):
        return float(np.sqrt(np.trapezoid(v[sel]**2,t[sel])/(t[-1]-t[sel][0])))
    return dict(rms_as_m_s2=rms(a), rms_carga_N=rms(carga),
                pico_as_m_s2=float(np.max(abs(a[sel]))),
                Nmin_N=float(np.min(normal)), curso_max_cm=float(100*np.max(abs(curso))),
                i_max_A=float(np.max(y[:,7])) if ramo else "",
                tempo_N_nao_positivo_s=float(np.trapezoid((normal<=0).astype(float),t)))

def salvar_csv(pasta, nome, linhas):
    with (pasta/nome).open("w",newline="",encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=linhas[0].keys())
        writer.writeheader()
        writer.writerows(linhas)

def varrer(pistas):
    linhas=[]
    for semente,(t,w) in pistas.items():
        for ramo, valores in ((0,PASSIVOS),(1,GANHOS)):
            for ganho in valores:
                y = simular(t,w,ganho) if ramo else simular(t,w,3000,ganho)
                linhas.append(dict(tipo="semiativa" if ramo else "passiva", ganho_Ns_m=ganho,
                                   semente=semente, **metricas(t,w,y,5,ramo)))
    return linhas

def agregar(linhas, chave, campos):
    grupo = {}
    for r in linhas:
        grupo.setdefault(tuple(r[c] for c in chave),[]).append(r)
    return [dict(zip(chave,k), n=len(rs),
                 **{c:float(np.mean([r[c] for r in rs])) for c in campos},
                 Nmin_pior_N=min(r["Nmin_N"] for r in rs),
                 N_nao_positiva=sum(r["Nmin_N"]<=0 for r in rs))
            for k,rs in grupo.items()]

def selecionar(agregados, referencia, conforto_passivo):
    semis = [r for r in agregados if r["tipo"]=="semiativa"]
    admissiveis = [r for r in semis if r["N_nao_positiva"]==0
                   and r["rms_carga_N"]<=referencia and r["rms_as_m_s2"]<conforto_passivo]
    if admissiveis:
        return min(admissiveis,key=lambda r:r["rms_as_m_s2"]), "contato_e_carga"
    return max(semis,key=lambda r:(r["Nmin_pior_N"],-r["rms_as_m_s2"])), "exploratorio_maior_N_min"

def comparar(pasta, pistas, ganho):
    linhas=[]
    for cenario,semente,(t,w) in [("lombada",0,lombada())]+[
            ("iso8608",s,val) for s,val in pistas.items()]:
        y=simular(t,w,ganho)
        for ramo,tipo in enumerate(("passiva","semiativa")):
            linhas.append(dict(cenario=cenario,semente=semente,tipo=tipo,
                               **metricas(t,w,y,1 if not semente else 5,ramo)))
        if semente in (0,1):
            np.savez_compressed(pasta/f"sinais_{cenario}.npz", dados=np.column_stack((t,w,y)),
                                colunas=COLUNAS)
            plotar_tempo(pasta,cenario,t,w,y,ganho)
    return linhas

def plotar_tempo(pasta,cenario,t,w,y,ganho):
    titulo = "Lombada de 5 cm" if cenario=="lombada" else "Pista ISO 8608 classe C · 72 km/h · semente 1"
    fig, ax=plt.subplots(3,1,figsize=(10,7),sharex=True,layout="constrained")
    fig.suptitle(titulo, fontsize=16, fontweight="semibold")
    ax[0].plot(t,100*w,color="#475569")
    ax[0].set_ylabel("Pista [cm]")
    for j,(rotulo,off) in enumerate((("Aceleração [m/s²]",0),("Força normal [N]",2)),1):
        for i,(label,color) in enumerate((("Passiva · c = 1500 N·s/m","#264c73"),(f"Semiativa · c_sky = {ganho} N·s/m","#c04b32"))):
            ax[j].plot(t,y[:,off+i]+(PESO if j==2 else 0),label=label,color=color,lw=1.05)
        ax[j].set_ylabel(rotulo)
    ax[1].legend(loc="upper right",fontsize=9)
    ax[2].axhline(0,color="#64748b",lw=.8,linestyle="--")
    ax[2].set_xlabel("Tempo [s]")
    ax[2].set_xlim((0,5) if cenario=="lombada" else (5,10))
    for eixo in ax: eixo.grid(alpha=.24)
    fig.savefig(pasta/f"resposta_{cenario}.png",dpi=180)
    plt.close(fig)

def plotar_varredura(pasta,agregados,ganho):
    fig, ax=plt.subplots(figsize=(10,6),layout="constrained")
    for tipo,cor in (("passiva","#264c73"),("semiativa","#c04b32")):
        rs=[r for r in agregados if r["tipo"]==tipo]
        ax.plot([r["rms_carga_N"] for r in rs],[r["rms_as_m_s2"] for r in rs],
                color=cor,label=tipo.capitalize())
        for r in rs:
            x,z=r["rms_carga_N"],r["rms_as_m_s2"]
            ax.scatter(x,z,c=cor,marker="x" if r["N_nao_positiva"] else "o",zorder=3)
            if r["ganho_Ns_m"] in (600, 1500, 2400, 3000, 8000, ganho):
                ax.annotate(str(r["ganho_Ns_m"]),(x,z),xytext=(3,6),
                            textcoords="offset points",fontsize=8,color=cor)
            if tipo=="semiativa" and r["ganho_Ns_m"]==ganho:
                ax.scatter(x,z,s=120,facecolor="none",edgecolor=cor,linewidth=1.4)
    ax.set(title="Conforto × aderência · pista classe C · média de cinco sementes",
           xlabel="Carga dinâmica do pneu, RMS [N]",ylabel="Aceleração da carroceria, RMS [m/s²]")
    ax.scatter([],[],c="#64748b",marker="x",label="N ≤ 0 em pelo menos uma semente")
    ax.legend(title="Valores indicados em N·s/m"); ax.grid(alpha=.24)
    fig.savefig(pasta/"conforto_aderencia.png",dpi=180)
    plt.close(fig)

def main():
    pasta=REPO / "versoes" / "v3" / "resultados"
    pasta.mkdir(exist_ok=True)
    pistas={s:pista_iso(s) for s in SEMENTES}
    campos=("rms_as_m_s2","rms_carga_N","pico_as_m_s2","curso_max_cm","tempo_N_nao_positivo_s")
    varredura=varrer(pistas)
    agregados=agregar(varredura,("tipo","ganho_Ns_m"),campos)
    passiva = [metricas(t,w,simular(t,w,3000),5,0) for t,w in pistas.values()]
    referencia = float(np.mean([r["rms_carga_N"] for r in passiva]))
    conforto_passivo = float(np.mean([r["rms_as_m_s2"] for r in passiva]))
    candidato,regra=selecionar(agregados,referencia,conforto_passivo)
    ganho=candidato["ganho_Ns_m"]
    salvar_csv(pasta,"varredura_por_semente.csv",varredura)
    salvar_csv(pasta,"varredura_resumo.csv",agregados)
    salvar_csv(pasta,"selecao.csv",[dict(criterio=regra,limite_carga_N=referencia,**candidato)])
    linhas=comparar(pasta,pistas,ganho)
    salvar_csv(pasta,"metricas_por_cenario.csv",linhas)
    salvar_csv(pasta,"tabela_comparativa.csv",agregar(linhas,("cenario","tipo"),campos))
    plotar_varredura(pasta,agregados,ganho)
    sensibilidade=[]
    for ts,tau in ((.0005,.015),(.001,.015),(.002,.015),(.001,.0075),(.001,.030)):
        for s,(t,w) in pistas.items():
            sensibilidade.append(dict(Ts_ms=1000*ts,tau_ms=1000*tau,semente=s,
                **metricas(t,w,simular(t,w,ganho,ts=ts,tau=tau),5)))
    salvar_csv(pasta,"sensibilidade_por_semente.csv",sensibilidade)
    salvar_csv(pasta,"sensibilidade_resumo.csv",agregar(sensibilidade,("Ts_ms","tau_ms"),campos))
    print(f"Ganho avaliado: {ganho} N·s/m ({regra})")

if __name__=="__main__":
    main()
