function fig = animar_suspensao(d, manual)
% Reproducao dos sinais registrados do Simulink, sem sintetizar os movimentos.
% Timer nao bloqueante; fechar a janela encerra e apaga o timer.
% manual=true permite exportar quadros em tempos exatos, sem timer.
if nargin<2, manual=false; end
tm=[];
p.escalaVisual=d.visual.escala; p.velocidade=d.visual.velocidade_mapa; p.cpass=d.parametros.c_pass;
fig=figure('Name',['Suspensao | ' d.nome],'Color',[0.96 0.97 0.99], ...
 'Position',[80 80 1200 720],'CloseRequestFcn',@fechar);
pausado=false; tempo=0; velocidade=d.visual.reproducao; ultimo=tic;
uicontrol(fig,'Style','pushbutton','String','Reproduzir','Position',[30 20 100 30],'Callback',@play);
uicontrol(fig,'Style','pushbutton','String','Pausar','Position',[140 20 100 30],'Callback',@pauseplay);
uicontrol(fig,'Style','pushbutton','String','Reiniciar','Position',[250 20 100 30],'Callback',@reset);
uicontrol(fig,'Style','text','String','Velocidade','Position',[370 22 85 22]);
uicontrol(fig,'Style','popupmenu','String',{'0.25x','0.5x','1x','2x','4x'}, ...
 'Value',2,'Position',[460 20 80 30],'Callback',@speed);
status=uicontrol(fig,'Style','text','Position',[570 15 580 35],'FontSize',11);
cores={[0.25 0.45 0.85],[0.12 0.65 0.42]}; nomes={'Passiva','Semiativa'};
ax=gobjects(1,2);
vazio=struct('road',[],'body',[],'wheel',[],'spring',[],'damper',[],'rod',[],'axle',[],'info',[]);
h=repmat(vazio,1,2);
for j=1:2
 ax(j)=axes(fig,'Position',[0.06+(j-1)*0.49 0.16 0.43 0.76]);
 hold(ax(j),'on'); axis(ax(j),[-1.7 1.7 -0.5 2.5]); axis(ax(j),'equal');
 title(ax(j),nomes{j}); xlabel(ax(j),'Distancia local (m)'); ylabel(ax(j),'Geometria esquematica (m)'); grid(ax(j),'on');
 h(j).road=plot(ax(j),nan,nan,'k','LineWidth',2);
 h(j).body=patch(ax(j),nan,nan,cores{j},'EdgeColor','none');
 h(j).wheel=patch(ax(j),nan,nan,[0.2 0.22 0.25]);
 h(j).spring=plot(ax(j),nan,nan,'Color',cores{j},'LineWidth',2);
 h(j).damper=plot(ax(j),nan,nan,'Color',[0.75 0.3 0.1],'LineWidth',5);
 h(j).rod=plot(ax(j),nan,nan,'Color',[0.3 0.3 0.3],'LineWidth',2);
 h(j).axle=plot(ax(j),nan,nan,'k','LineWidth',3);
 h(j).info=text(ax(j),-1.6,2.25,'','FontSize',10);
end
desenhar();
set(fig,'DeleteFcn',@limpar_timer);
setappdata(fig,'renderizar_tempo',@ir_para_tempo);
if ~manual
 tm=timer('ExecutionMode','fixedSpacing','Period',round(1000/d.visual.fps)/1000,'BusyMode','drop','TimerFcn',@tick);
 start(tm);
end
function ir_para_tempo(t)
 tempo=max(d.t(1),min(d.t(end),t));
 desenhar();
end
function tick(~,~)
 if ~isgraphics(fig), limpar_timer(); return; end
 dt=toc(ultimo); ultimo=tic;
 if ~pausado, tempo=min(d.t(end),tempo+dt*velocidade); end
 if tempo>=d.t(end), pausado=true; end
 desenhar();
end
function desenhar()
 y=interp1(d.t,d.y,tempo,'linear'); g=p.escalaVisual;
 x=linspace(-1.7,1.7,350);
 % Perfil espacial r(t+x/v): irregularidades deslocam-se da direita para esquerda.
 pista=interp1(d.t,d.y(:,1),tempo+x/p.velocidade,'linear',0)*g;
 set(status,'String',sprintf('%s | t = %.2f s | deslocamentos ampliados %.1fx (ambos)',d.nome,tempo,g));
 for jj=1:2
  ix=2+(jj-1)*5; zs=y(ix); zu=y(ix+2);
  yc=1.5+g*zs; yw=0.3+g*zu; ang=linspace(0,2*pi,80);
  set(h(jj).road,'XData',x,'YData',pista);
  set(h(jj).body,'XData',[-1 1 1 -1],'YData',yc+[0 0 0.35 0.35]);
  set(h(jj).wheel,'XData',0.3*cos(ang),'YData',yw+0.3*sin(ang));
  set(h(jj).axle,'XData',[-0.65 0.65],'YData',[yw yw]);
  sy=linspace(yw,yc,17); sx=-0.45+0.12*(-1).^(0:16); sx([1 end])=-0.45;
  set(h(jj).spring,'XData',sx,'YData',sy);
  set(h(jj).damper,'XData',[0.45 0.45],'YData',[yw yw+0.43]);
  set(h(jj).rod,'XData',[0.45 0.45],'YData',[yw+0.25 yc]);
  if jj==1, c=p.cpass; nn=interp1(d.t,d.N_pass,tempo); else, c=y(13); nn=interp1(d.t,d.N_semi,tempo); end
  set(h(jj).info,'String',sprintf('zs=%+.1f mm | zu=%+.1f mm\nc=%.0f N s/m',1000*zs,1000*zu,c));
  if nn<=0, set(h(jj).info,'String',sprintf('N = %.0f N: perda de contato prevista\nPneu bilateral: resposta limitada',nn),'Color',[0.8 0.1 0.1]); else, set(h(jj).info,'Color',[0.1 0.1 0.1]); end
 end
 drawnow limitrate;
end
function play(~,~), if tempo>=d.t(end), tempo=0; end; pausado=false; ultimo=tic; end
function pauseplay(~,~), pausado=true; end
function reset(~,~), tempo=0; pausado=false; ultimo=tic; desenhar(); end
function speed(src,~), v=[0.25 0.5 1 2 4]; velocidade=v(src.Value); end
function fechar(~,~)
 limpar_timer();
 delete(fig);
end
function limpar_timer(varargin)
 if ~isempty(tm) && isvalid(tm), stop(tm); delete(tm); end
end
end
