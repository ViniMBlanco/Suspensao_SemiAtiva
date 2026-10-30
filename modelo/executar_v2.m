function [T,dados]=executar_v2(validar)
% EXECUTAR_V2 Ensaio classe C, 72 km/h, 5 sementes pareadas e validacao.
% [T,dados]=executar_v2;  % tudo local, nenhum comando Git
% executar_v2(false) omite somente a verificacao independente e dt/2.
if nargin<1, validar=true; end
raiz=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(raiz,'modelo'),fullfile(raiz,'visualizacao'),fullfile(raiz,'testes'));
pasta=fullfile(raiz,'versoes','v2','resultados');
if ~isfolder(pasta), mkdir(pasta); end
cfg=carregar_versao('v2');
arquivo=fullfile(raiz,'versoes','v2','suspensao_semiativa_v2.slx');
salvo=dir(arquivo);
fontes=[dir(fullfile(raiz,'modelo','montar_modelo.m'));dir(fullfile(raiz,'modelo','organizar_diagrama.m'))];
if isempty(salvo) || max([fontes.datenum])>salvo.datenum, montar_modelo(false,'v2'); end
load_system(arquivo);
dados=struct([]); linhas=cell(5,1); perfis=cell(5,1);
for s=1:5
 p=cfg; p.pistas.iso8608.semente=s;
 [pista,~,t0,meta]=gerar_pista('iso8608',p.pistas,p.dt);
 fprintf('V2 ISO classe C / semente %d de 5...\n',s);
 in=entrada_v2(p,pista); out=sim(in);
 d=coletar_sinais(out,p,'iso8608',t0); d.pista_meta=meta;
 d.metricas=metricas_suspensao(d);
 d.metricas.semente=s;
 d.metricas.sigma_pista_m=std(pista(:,2),1);
 d.metricas.sigma_teorico_m=meta.sigma_teorico_m;
 d.metricas.pico_pista_centrada_m=max(abs(pista(:,2)-mean(pista(:,2))));
 peso=(p.m_s+p.m_u)*p.g;
 d.metricas.DLC_passivo=d.metricas.rms_carga_pneu_passivo_N/peso;
 d.metricas.DLC_semi=d.metricas.rms_carga_pneu_semi_N/peso;
 d.metricas.tempo_N_nao_positivo_passivo_s=trapz(d.t,double(d.N_pass<=0));
 d.metricas.tempo_N_nao_positivo_semi_s=trapz(d.t,double(d.N_semi<=0));
 inteiro=d; inteiro.t_metrica=0; mi=metricas_suspensao(inteiro);
 d.metricas.rms_as_0_30_passivo=mi.rms_as_passivo;
 d.metricas.rms_as_0_30_semi=mi.rms_as_semi;
 d.metricas.melhora_0_30_pct=mi.melhora_rms_pct;
 tardio=d; tardio.t_metrica=10; mt=metricas_suspensao(tardio);
 d.metricas.melhora_10_30_pct=mt.melhora_rms_pct;
 if s==1, dados=repmat(d,1,5); else, dados(s)=d; end
 linhas{s}=struct2table(d.metricas); perfis{s}=pista;
 fprintf('  RMS: %.6f -> %.6f m/s2; melhora %.3f%%; Nmin %.1f / %.1f N\n', ...
  d.metricas.rms_as_passivo,d.metricas.rms_as_semi,d.metricas.melhora_rms_pct, ...
  d.metricas.N_min_passivo_N,d.metricas.N_min_semi_N);
end
T=vertcat(linhas{:});
writetable(T,fullfile(pasta,'metricas_sementes.csv'));
writetable(T(1,:),fullfile(pasta,'metricas.csv'));
contato=T(:,{'semente','N_min_passivo_N','N_min_semi_N', ...
 'tempo_N_nao_positivo_passivo_s','tempo_N_nao_positivo_semi_s'});
primeiro_p=nan(5,1); primeiro_s=primeiro_p;
for j=1:5
 ip=find(dados(j).N_pass<=0,1); is=find(dados(j).N_semi<=0,1);
 if ~isempty(ip), primeiro_p(j)=dados(j).t(ip); end
 if ~isempty(is), primeiro_s(j)=dados(j).t(is); end
end
contato.primeiro_N_nao_positivo_passivo_s=primeiro_p;
contato.primeiro_N_nao_positivo_semi_s=primeiro_s;
writetable(contato,fullfile(pasta,'diagnostico_contato.csv'));
campos={'rms_as_passivo','rms_as_semi','melhora_rms_pct', ...
 'rms_carga_pneu_passivo_N','rms_carga_pneu_semi_N','DLC_passivo','DLC_semi', ...
 'curso_max_passivo_cm','curso_max_semi_cm','sigma_pista_m'};
media=zeros(numel(campos),1); desvio=media;
for k=1:numel(campos), v=T.(campos{k}); media(k)=mean(v); desvio(k)=std(v); end
resumo=table(string(campos'),media,desvio,'VariableNames',{'metrica','media','desvio_entre_sementes'});
writetable(resumo,fullfile(pasta,'resumo_cinco_sementes.csv'));
save(fullfile(pasta,'dados_simulacao.mat'),'dados','T','resumo','-v7.3');
perfil=table(perfis{1}(:,1),20*perfis{1}(:,1),perfis{1}(:,2), ...
 'VariableNames',{'tempo_s','distancia_m','altura_m'});
writetable(perfil,fullfile(pasta,'perfil_iso8608_semente1.csv'));
plotar_resultados(dados(1),pasta);
diagnostico_pista_v2(dados,pasta);
plotar_v2(dados,pasta);
print('-ssuspensao_semiativa_v2','-dpng','-r130',fullfile(pasta,'diagrama_v2.png'));
checagens=table;
if validar, checagens=validar_v2(dados,pasta); end
escrever_relatorio_v2(dados,T,resumo,checagens,pasta);
% Estado padrao ao final: semente 1, passo original e ganho original.
carregar_versao('v2');
disp(T(:,{'semente','rms_as_passivo','rms_as_semi','melhora_rms_pct','N_min_passivo_N','N_min_semi_N'}));
fprintf('V2 concluida. Resultados: %s\n',pasta);
end
