function figuras = plotar_comparacao_aceleracoes(versao, abrir)
% Reproduz o formato das figuras comparativas publicadas na v1.
% plotar_comparacao_aceleracoes('v1') abre as tres janelas.
% plotar_comparacao_aceleracoes('v1',false) exporta sem deixar janelas abertas.
% Usa dados_simulacao.mat gerado por rodar_versao; nao modifica o modelo.
if nargin<1, versao='v1'; end
if nargin<2, abrir=true; end
raiz=fileparts(fileparts(mfilename('fullpath')));
fonte=fullfile(raiz,'versoes',versao,'resultados','dados_simulacao.mat');
assert(isfile(fonte),'Execute rodar_versao antes de gerar as comparacoes.');
s=load(fonte,'dados');
% A v2 guarda cinco realizacoes da mesma pista; a figura de referencia usa a 1.
if strcmp(versao,'v2'), s.dados=s.dados(1); end
destino=fullfile(raiz,'versoes',versao,'resultados','comparacao_aceleracoes');
if ~isfolder(destino), mkdir(destino); end
figuras=gobjects(1,numel(s.dados));
for k=1:numel(s.dados)
    d=s.dados(k); t=d.t; ap=d.y(:,6); as=d.y(:,11);
    sel=t>=d.t_metrica; tt=t(sel);
    rp=sqrt(trapz(tt,ap(sel).^2)/(tt(end)-tt(1)));
    rs=sqrt(trapz(tt,as(sel).^2)/(tt(end)-tt(1)));
    reducao=100*(1-rs/rp);
    f=figure('Name',[upper(versao) ' | Aceleracao vertical | ' d.nome], ...
        'Visible','off','Color','w','Position',[60+20*k 60+20*k 1400 850]); figuras(k)=f;
    tiledlayout(f,2,2,'Padding','compact','TileSpacing','compact');
    a=nexttile([1 2]); curvas(a,t,ap,as);
    title(a,'Aceleracao vertical da carroceria - resposta completa');
    xline(a,d.t_metrica,':','Inicio da janela RMS','HandleVisibility','off');
    b=nexttile; curvas(b,t,ap,as);
    if strcmp(d.nome,'lombada'), xlim(b,[.9 3]);
    elseif strcmp(d.nome,'senoide'), xlim(b,[10 15]);
    elseif strcmp(d.nome,'iso8608'), xlim(b,[10 13]);
    else, xlim(b,[.98 1.35]); end
    title(b,'Detalhe temporal (zoom; nao altera a janela de RMS)');
    c=nexttile;
    barras=bar(c,[rp rs],'FaceColor','flat');
    barras.CData=[.2 .4 .8;0 .55 .3];
    set(c,'XTick',1:2,'XTickLabel',{'Passiva','Semiativa (ganho 3000)'});
    ylabel(c,'RMS da aceleracao [m/s^2]'); ylim(c,[0 1.25*max(rp,rs)]); grid(c,'on');
    text(c,1,rp,sprintf(' %.5f',rp),'HorizontalAlignment','center','VerticalAlignment','bottom');
    text(c,2,rs,sprintf(' %.5f',rs),'HorizontalAlignment','center','VerticalAlignment','bottom');
    if strcmp(d.nome,'degrau')
        titulo='Comparacao matematica: perda de contato prevista';
        for ax=[a b]
            xline(ax,t(find(d.N_semi<=0,1)),'r:','N <= 0: validade fisica limitada','HandleVisibility','off');
        end
    else
        titulo=sprintf('Reducao do RMS: %.2f%%',reducao);
    end
    titulos={titulo,sprintf('RMS nao ponderado | janela %.1f a %.1f s',d.t_metrica,t(end))};
    if strcmp(d.nome,'iso8608')
        titulos={titulo,sprintf('Diferenca de RMS: %.5f m/s^2',rp-rs),titulos{2}};
    end
    title(c,titulos);
    cabecalho=[upper(versao) ' | ' upper(d.nome) ' | Mesma pista: passiva x semiativa atual'];
    if strcmp(d.nome,'iso8608')
        cabecalho={ ...
            'V2 | ISO 8608 classe C | 72 km/h | Semente 1 | Passiva x semiativa', ...
            'Modelo linear: ha instantes com N <= 0; interpretacao fisica limitada'};
    end
    sgtitle(f,cabecalho);
    drawnow;
    exportgraphics(f,fullfile(destino,['aceleracao_' d.nome '.png']),'Resolution',150);
    exportgraphics(f,fullfile(fileparts(destino),[versao '_' d.nome '.jpeg']),'Resolution',100);
    savefig(f,fullfile(destino,['aceleracao_' d.nome '.fig']));
    fprintf('%s: RMS passiva %.8f, semiativa %.8f; reducao %.4f%%\n',d.nome,rp,rs,reducao);
end
if abrir
    set(figuras,'Visible','on'); figure(figuras(1));
else
    close(figuras);
end
disp('COMPARACOES_DIRETAS_ABERTAS');
end
function curvas(ax,t,ap,as)
plot(ax,t,ap,'--','Color',[.2 .4 .8],'LineWidth',1.4); hold(ax,'on');
plot(ax,t,as,'Color',[0 .55 .3],'LineWidth',1.3);
yline(ax,0,':','HandleVisibility','off');
xlabel(ax,'Tempo [s]'); ylabel(ax,'a_s [m/s^2]'); grid(ax,'on');
legend(ax,'Passiva','Semiativa (ganho 3000)','Location','best');
end
