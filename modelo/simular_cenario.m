function d = simular_cenario(tipo)
% SIMULAR_CENARIO Calcula e anima uma pista da v1.
%   simular_cenario('lombada')
%   simular_cenario('senoide')
%   simular_cenario('degrau')
tipo=validatestring(tipo,{'lombada','senoide','degrau'});
pasta=fileparts(mfilename('fullpath'));
raiz=fileparts(pasta);
addpath(pasta,fullfile(raiz,'visualizacao'));
cfg=carregar_versao('v1');
arquivo=fullfile(pasta,'suspensao_semiativa.slx');
fontes=dir(fullfile(pasta,'*.m')); salvo=dir(arquivo);
if isempty(salvo)||max([fontes.datenum])>salvo.datenum
    montar_modelo(false);
end
load_system(arquivo);
[pista,t_final,t_metrica]=gerar_pista(tipo,cfg.pistas,cfg.dt);
% Mantem a mesma pista no workspace para uma nova execucao pelo Run do Simulink.
assignin('base','pista',pista);
assignin('base','t_final',t_final);
assignin('base','pista_tipo',tipo);
in=Simulink.SimulationInput('suspensao_semiativa');
in=in.setVariable('pista',pista);
in=in.setVariable('t_final',t_final);
fprintf('Simulando v1 / %s...\n',tipo);
out=sim(in);
d=coletar_sinais(out,cfg,tipo,t_metrica);
d.metricas=metricas_suspensao(d);
if ~d.metricas.contato_valido_passivo || ~d.metricas.contato_valido_semi
    warning('Suspensao:Contato','%s: N <= 0. O pneu linear bilateral nao representa perda de contato.',tipo);
end
plotar_resultados(d,fullfile(raiz,'versoes','v1','resultados'));
open_system(arquivo);
fig=animar_suspensao(d);
set(fig,'Name',['v1 | ' tipo]);
figure(fig);
fprintf('Simulacao concluida. A animacao usa os resultados calculados agora.\n');
end
