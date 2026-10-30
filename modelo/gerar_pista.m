function [pista, t_final, t_metrica, meta] = gerar_pista(tipo, pistas, dt)
% GERAR_PISTA  Perfil da pista w(t) no formato [t w] do bloco From Workspace.
%   tipo:   'lombada' | 'senoide' | 'degrau' | 'iso8608'
%   pistas: struct com os dados de cada pista (definido no parametros.m)
%   t_metrica: instante a partir do qual as metricas sao calculadas

meta=struct;
if ~isfield(pistas, tipo)
    error('Pista "%s" nao existe nesta versao.', tipo);
end
p = pistas.(tipo);
t_final = p.t_final;
t = (0:dt:t_final).';

switch tipo
    case 'iso8608'
        % PSD unilateral em ciclos/m. Energia integrada exata de cada banda.
        assert(p.n_min>0 && p.n_max>p.n_min && p.V>0 && p.N>=1);
        assert(p.V*p.n_max<1/(2*dt),'Frequencia acima de Nyquist');
        bordas=logspace(log10(p.n_min),log10(p.n_max),p.N+1)';
        n=sqrt(bordas(1:end-1).*bordas(2:end));
        A=sqrt(2*p.Gd0*p.n0^2*(1./bordas(1:end-1)-1./bordas(2:end)));
        % RandStream local: reproducibilidade sem modificar o RNG do usuario.
        fluxo=RandStream('mt19937ar','Seed',p.semente);
        fase=2*pi*rand(fluxo,p.N,1);
        w=zeros(size(t));
        for k=1:p.N
            w=w+A(k)*cos(2*pi*n(k)*p.V*t+fase(k));
        end
        % Origem vertical arbitraria: w(0)=0, sem rampa ou escala artificial.
        origem=w(1); w=w-origem;
        t_metrica=p.t_metrica;
        meta=struct('n',n,'bordas',bordas,'A',A,'fase',fase, ...
            'origem_subtraida_m',origem,'sigma_teorico_m',sqrt(sum(A.^2)/2), ...
            'semente',p.semente,'V',p.V,'Gd0',p.Gd0);
    case 'lombada'
        % 1 - cos: sobe e desce suave, comeca e termina com inclinacao zero
        fase = (t - p.t_ini)/p.duracao;
        w = 0.5*p.altura*(1 - cos(2*pi*fase));
        w(fase < 0 | fase > 1) = 0;
        t_metrica = p.t_ini;
    case 'senoide'
        w = p.amplitude*sin(p.omega*t);
        t_metrica = p.t_metrica;
    case 'degrau'
        % Rampa curta para suavizar o salto de forca do pneu.
        % No pneu elastico sem amortecimento, um degrau de altura gera forca
        % finita k_t*altura; nao gera forca infinita.
        w = p.altura*min(max((t - p.t_ini)/p.t_rampa, 0), 1);
        t_metrica = p.t_ini;
end

pista = [t w];
end
