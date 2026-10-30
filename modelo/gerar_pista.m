function [pista, t_final, t_metrica] = gerar_pista(tipo, pistas, dt)
% GERAR_PISTA  Perfil da pista w(t) no formato [t w] do bloco From Workspace.
%   tipo:   'lombada' | 'senoide' | 'degrau'
%   pistas: struct com os dados de cada pista (definido no parametros.m)
%   t_metrica: instante a partir do qual as metricas sao calculadas

if ~isfield(pistas, tipo)
    error('Pista "%s" nao existe. Use lombada, senoide ou degrau.', tipo);
end
p = pistas.(tipo);
t_final = p.t_final;
t = (0:dt:t_final).';

switch tipo
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
