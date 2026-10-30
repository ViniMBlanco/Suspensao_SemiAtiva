function D=diagnostico_pista_v2(dados,pasta)
% Periodograma unilateral espacial, janela Hann e integracao em bandas log.
% Sem depender do Signal Processing Toolbox. PSD medida e uma estimativa finita.
p=dados(1).parametros.pistas.iso8608;
N=numel(dados(1).t)-1; dx=p.V*dados(1).parametros.dt; fs=1/dx;
n=(0:floor(N/2))'*fs/N;
janela=0.5-0.5*cos(2*pi*(0:N-1)'/(N-1));
S=zeros(numel(n),numel(dados));
for j=1:numel(dados)
 w=detrend(dados(j).y(1:N,1),'linear');
 f=fft(w.*janela); v=abs(f(1:numel(n))).^2/(fs*sum(janela.^2));
 v(2:end-1)=2*v(2:end-1); S(:,j)=v;
end
e=logspace(log10(p.n_min),log10(p.n_max),25)';
c=sqrt(e(1:end-1).*e(2:end)); sb=nan(24,numel(dados));
for k=1:24
 idx=n>=e(k)&n<e(k+1);
 if nnz(idx)>=2, sb(k,:)=mean(S(idx,:),1); end
end
sd=mean(sb,2); alvo=p.Gd0*(c/p.n0).^-2;
D=table(c,alvo,sb(:,1),sd,'VariableNames', ...
 {'n_ciclos_m','PSD_alvo_m3','PSD_semente1_m3','PSD_media5_m3'});
writetable(D,fullfile(pasta,'PSD_pista.csv'));
ok=c>=0.03 & c<=1.5 & isfinite(sd);
G_estimado=exp(mean(log(sd(ok).*(c(ok)/p.n0).^2)));
coef=polyfit(log(c(ok)),log(sd(ok)),1);
auditoria=table(p.Gd0,G_estimado,coef(1),sqrt(p.Gd0*p.n0^2*(1/p.n_min-1/p.n_max)), ...
 'VariableNames',{'Gd0_alvo_m3','Gd0_estimado_media5_m3','inclinacao_estimada','sigma_teorico_m'});
writetable(auditoria,fullfile(pasta,'conferencia_classe_C.csv'));
f=figure('Visible','off','Position',[60 60 1250 820]);
tiledlayout(2,2,'TileSpacing','compact');
nexttile; plot(dados(1).t,p.V*0+1000*dados(1).y(:,1)); grid on;
xlabel('Tempo [s]'); ylabel('Altura [mm]'); title('Perfil aplicado - semente 1; w(0)=0');
nexttile; plot(p.V*dados(1).t,1000*dados(1).y(:,1)); grid on;
xlabel('Distancia [m]'); ylabel('Altura [mm]'); title('600 m a 72 km/h');
nexttile; loglog(c,alvo,'k--',c,sb(:,1),'-',c,sd,'-','LineWidth',1.4); hold on;
loglog(c,128e-6*(c/p.n0).^-2,':',c,512e-6*(c/p.n0).^-2,':','Color',[.5 .5 .5]);
grid on; xlabel('Frequencia espacial [ciclos/m]'); ylabel('PSD unilateral [m^3]');
legend('Alvo classe C','Semente 1','Media de 5 sementes','Limites C','Location','southwest');
title(sprintf('PSD estimada; inclinacao %.2f (alvo -2)',coef(1)));
nexttile; bar(1:5,1000*arrayfun(@(d)d.metricas.sigma_pista_m,dados)); hold on;
yline(1000*auditoria.sigma_teorico_m,'k--','Teorico'); grid on;
xlabel('Semente'); ylabel('Desvio padrao [mm]'); title('Variabilidade dos trechos finitos');
sgtitle('V2 - verificacao da pista ISO 8608 sintetica, classe C');
exportgraphics(f,fullfile(pasta,'pista_e_PSD_v2.png'),'Resolution',160);
savefig(f,fullfile(pasta,'pista_e_PSD_v2.fig')); close(f);
end
