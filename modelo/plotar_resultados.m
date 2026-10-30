function plotar_resultados(d,pasta)
y=d.y; t=d.t; fig=figure('Visible','off','Position',[50 50 1450 950]);
limpeza=onCleanup(@()close(fig));
tiledlayout(fig,4,3,'TileSpacing','compact');
painel(t,y(:,[2 7]),'Carroceria','m',{'Passiva','Semiativa'});
painel(t,y(:,[4 9]),'Roda','m',{});
painel(t,y(:,1),'Estrada','m',{});
painel(t,y(:,[6 11]),'Aceleracao carroceria','m/s^2',{});
painel(t,y(:,[3 8]),'Velocidade carroceria','m/s',{});
painel(t,[y(:,2)-y(:,4),y(:,7)-y(:,9)],'Curso suspensao','m',{});
painel(t,y(:,[12 13]),'Amortecimento','N s/m',{'Pedido','Efetivo'});
painel(t,y(:,[14 15]),'Corrente','A',{'Referencia','Real'});
painel(t,y(:,16),'Tensao aplicada','V',{});
painel(t,[y(:,4)-y(:,1),y(:,9)-y(:,1)],'Deflexao pneu','m',{});
painel(t,[d.N_pass,d.N_semi],'Forca normal no pneu','N',{}); yline(0,'r:');
painel(t,y(:,13).*(y(:,8)-y(:,10)).^2,'Potencia dissipada semiativa','W',{});
titulo=sprintf('%s | %s | RMS sem ponderacao ISO',d.versao,d.nome);
if any(d.N_semi<=0)||any(d.N_pass<=0)
 titulo=[titulo ' | N <= 0: limite do modelo bilateral'];
end
sgtitle(titulo);
exportgraphics(fig,fullfile(pasta,sprintf('%s_%s.png',d.versao,d.nome)),'Resolution',130);
end
function painel(t,y,n,u,leg)
nexttile; plot(t,y,'LineWidth',1); grid on; title(n); ylabel(u); xlabel('t [s]');
if ~isempty(leg), legend(leg,'Location','best'); end
end
