function [T,dados] = rodar_versao(versao, tipos)
% RODAR_VERSAO Simula a versao e salva sinais reais, metricas e figuras.
%   [T,dados]=rodar_versao('v1'); animar_suspensao(dados(1));
if strcmp(versao,'v2') && nargin<2
 [T,dados]=executar_v2; return;
end
if nargin<2
 if strcmp(versao,'v2'), tipos={'iso8608'}; else, tipos={'lombada','senoide','degrau'}; end
end
pasta_modelo=fileparts(mfilename('fullpath'));
pasta_res=fullfile(fileparts(pasta_modelo),'versoes',versao,'resultados');
if ~exist(pasta_res,'dir'), mkdir(pasta_res); end
addpath(pasta_modelo);
cfg=carregar_versao(versao); mdl='suspensao_semiativa';
arquivo=fullfile(pasta_modelo,[mdl '.slx']); fontes=dir(fullfile(pasta_modelo,'*.m'));
if strcmp(versao,'v2')
 mdl='suspensao_semiativa_v2'; arquivo=fullfile(fileparts(pasta_res),[mdl '.slx']);
end
salvo=dir(arquivo);
if isempty(salvo)||max([fontes.datenum])>salvo.datenum
 montar_modelo(false,versao);
end
load_system(arquivo);
linhas=cell(numel(tipos),1); dados=struct([]);
for k=1:numel(tipos)
 tipo=tipos{k};
 [pista,t_final,t_metrica]=gerar_pista(tipo,cfg.pistas,cfg.dt);
 in=Simulink.SimulationInput(mdl);
 in=in.setVariable('pista',pista); in=in.setVariable('t_final',t_final);
 fprintf('Simulando %s / %s...\n',versao,tipo);
 out=sim(in);
 d=coletar_sinais(out,cfg,tipo,t_metrica); d.metricas=metricas_suspensao(d);
 if k==1, dados=repmat(d,1,numel(tipos)); else, dados(k)=d; end
 linhas{k}=[table(string(tipo),'VariableNames',{'pista'}),struct2table(d.metricas)];
 if ~d.metricas.contato_valido_passivo || ~d.metricas.contato_valido_semi
  warning('Suspensao:Contato','%s: N <= 0. O pneu linear bilateral nao representa perda de contato; resultado nesse trecho e limitado.',tipo);
 end
 plotar_resultados(d,pasta_res);
end
T=vertcat(linhas{:}); writetable(T,fullfile(pasta_res,'metricas.csv'));
save(fullfile(pasta_res,'dados_simulacao.mat'),'dados','T','-v7');
print(['-s' mdl],'-dpng','-r110',fullfile(pasta_res,['diagrama_' versao '.png']));
disp(T); fprintf('Resultados salvos em %s\n',pasta_res);
end
