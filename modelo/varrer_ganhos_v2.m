function T=varrer_ganhos_v2(ganhos,amortecimentos,semente)
% Preparacao da semana 3. Nao altera parametros.m nem salva o .slx.
% T=varrer_ganhos_v2;  % 10 ganhos Skyhook + 10 amortecimentos passivos
% Nao e executado por executar_v2: ganho oficial da v2 continua 3000.
if nargin<1, ganhos=[600 900 1200 1500 2000 2500 3000 4000 6000 8000]; end
if nargin<2, amortecimentos=linspace(600,2400,10); end
if nargin<3, semente=1; end
cfg=carregar_versao('v2'); cfg.pistas.iso8608.semente=semente;
raiz=fileparts(fileparts(mfilename('fullpath')));
arquivo=fullfile(raiz,'versoes','v2','suspensao_semiativa_v2.slx');
if ~isfile(arquivo), montar_modelo(false,'v2'); end
load_system(arquivo);
[w,~,t0]=gerar_pista('iso8608',cfg.pistas,cfg.dt);
linhas=cell(numel(ganhos)+numel(amortecimentos),1);
fim=onCleanup(@()carregar_versao('v2'));
for j=1:numel(linhas)
 p=cfg;
 if j<=numel(ganhos)
  p.c_sky=ganhos(j); tipo="semiativa"; valor=p.c_sky;
 else
  p.c_pass=amortecimentos(j-numel(ganhos)); tipo="passiva"; valor=p.c_pass;
 end
 out=sim(entrada_v2(p,w)); d=coletar_sinais(out,p,'iso8608',t0); m=metricas_suspensao(d);
 if tipo=="semiativa"
  rms=m.rms_as_semi; carga=m.rms_carga_pneu_semi_N; Nmin=m.N_min_semi_N; curso=m.curso_max_semi_cm;
 else
  rms=m.rms_as_passivo; carga=m.rms_carga_pneu_passivo_N; Nmin=m.N_min_passivo_N; curso=m.curso_max_passivo_cm;
 end
 linhas{j}=table(tipo,valor,semente,rms,carga,Nmin,curso,Nmin>0, ...
  'VariableNames',{'tipo','ganho_Ns_m','semente','rms_as','rms_carga_N','Nmin_N','curso_cm','contato_valido'});
end
T=vertcat(linhas{:}); pasta=fullfile(raiz,'versoes','v2','resultados','exploracao_ganhos');
if ~isfolder(pasta), mkdir(pasta); end
writetable(T,fullfile(pasta,sprintf('varredura_semente%d.csv',semente)));
f=figure; hold on; grid on;
for tipo=["passiva","semiativa"]
 idx=T.tipo==tipo; plot(T.rms_carga_N(idx),T.rms_as(idx),'-o','DisplayName',tipo);
 text(T.rms_carga_N(idx),T.rms_as(idx),string(T.ganho_Ns_m(idx)),'FontSize',8);
end
xlabel('RMS carga dinamica [N]'); ylabel('RMS aceleracao [m/s^2]'); legend('Location','best');
title('Exploracao de ganhos - nao altera a v2 de referencia');
exportgraphics(f,fullfile(pasta,sprintf('conforto_aderencia_semente%d.png',semente)),'Resolution',160);
end
