function arquivo=exportar_video_v2()
% Animacao dos sinais reais da v2, semente 1. Nao altera nem repete simulacoes.
raiz=fileparts(fileparts(mfilename('fullpath')));
fonte=fullfile(raiz,'versoes','v2','resultados','dados_simulacao.mat');
assert(isfile(fonte),'Execute executar_v2 antes de exportar.');
s=load(fonte,'dados'); d=s.dados(1);
pasta=fullfile(raiz,'versoes','v2','resultados','videos');
if ~isfolder(pasta), mkdir(pasta); end
fps=30; velocidade=0.5;
f=animar_suspensao(d,true); fechar=onCleanup(@()close(f));
set(f,'Position',[50 50 1280 720],'MenuBar','none','ToolBar','none','Resize','off');
controles=findall(f,'Type','uicontrol');
for j=1:numel(controles)
 if strcmp(get(controles(j),'Style'),'text') && get(controles(j),'FontSize')==11
  set(controles(j),'Position',[10 48 1260 28],'FontSize',12);
 else
  set(controles(j),'Visible','off');
 end
end
eixos=findall(f,'Type','axes');
for j=1:numel(eixos)
 p=get(eixos(j),'Position'); p(2)=0.20; p(4)=0.63; set(eixos(j),'Position',p);
end
nota(f,[.03 .93 .94 .055], ...
 'V2 | Pista ISO 8608 classe C | Passiva x Semiativa (Skyhook)',18,[.1 .1 .1]);
m=d.metricas;
nota(f,[.03 .875 .94 .05],sprintf( ...
 '72 km/h | Semente 1 | RMS a_s: %.3f -> %.3f m/s^2 | Reducao: %.2f%% (5-30 s)', ...
 m.rms_as_passivo,m.rms_as_semi,m.melhora_rms_pct),12,[.1 .1 .1]);
nota(f,[.02 .10 .96 .04], ...
 'Reproducao 0.5x | Deslocamentos ampliados 4x nos dois paineis | Mesma pista de 600 m',11,[.2 .2 .2]);
nota(f,[.02 .005 .96 .052], ...
 'N <= 0 previsto em alguns instantes: pneu linear nao representa separacao e recontato. RMS sem ponderacao ISO 2631.', ...
 10.5,[.70 .08 .08]);
renderizar=getappdata(f,'renderizar_tempo');
arquivo=fullfile(pasta,'v2_iso8608_classeC_72kmh.mp4');
v=VideoWriter(arquivo,'MPEG-4'); v.FrameRate=fps; v.Quality=95; open(v);
fecharvideo=onCleanup(@()close(v));
duracao=d.t(end)/velocidade+2; n=round(duracao*fps);
for q=0:n-1
 t=max(0,min(d.t(end),(q/fps-1)*velocidade));
 renderizar(t); drawnow;
 quadro=getframe(f); writeVideo(v,quadro);
 if q==round((1+10.5/velocidade)*fps)
  imwrite(quadro.cdata,fullfile(pasta,'preview_v2_iso8608.png'));
 end
 if mod(q,150)==0, fprintf('VIDEO_V2: %d/%d quadros\n',q,n); end
end
clear fecharvideo;
vr=VideoReader(arquivo);
assert(vr.Width==1280 && vr.Height==720);
assert(abs(vr.Duration-duracao)<1/fps+1e-3);
assert(abs(vr.FrameRate-fps)<1e-6);
readFrame(vr); vr.CurrentTime=vr.Duration-2/fps; readFrame(vr);
T=table(vr.Width,vr.Height,vr.FrameRate,vr.Duration,n, ...
 'VariableNames',{'largura','altura','fps','duracao_s','quadros'});
writetable(T,fullfile(pasta,'video_verificado.csv'));
fprintf('VIDEO_V2_VERIFICADO: %s | %.2f s\n',arquivo,vr.Duration);
end
function nota(f,pos,texto,tamanho,cor)
annotation(f,'textbox',pos,'String',texto,'EdgeColor','none', ...
 'HorizontalAlignment','center','FontSize',tamanho,'Color',cor);
end
