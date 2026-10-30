function arquivos = exportar_videos_v1()
% EXPORTAR_VIDEOS_V1 Exporta os tres resultados reais do Simulink para MP4.
% 1280x720, 30 fps, reproducao a 0.5x, escala vertical comum de 4x.
raiz=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(raiz,'modelo'),fullfile(raiz,'visualizacao'));
fonte=fullfile(raiz,'versoes','v1','resultados','dados_simulacao.mat');
if ~isfile(fonte)
    rodar_versao('v1');
end
s=load(fonte,'dados');
pasta=fullfile(raiz,'versoes','v1','resultados','videos');
if ~isfolder(pasta), mkdir(pasta); end
fps=30; velocidade=0.5; arquivos=cell(1,numel(s.dados));
relatorio=cell(numel(s.dados),6);
for k=1:numel(s.dados)
    d=s.dados(k);
    f=animar_suspensao(d,true);
    limpezaFigura=onCleanup(@()fechar_figura(f));
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
        p=get(eixos(j),'Position'); p(2)=0.20; p(4)=0.63;
        set(eixos(j),'Position',p);
    end
    titulo=['V1 | ' upper(d.nome) ' | Passiva x Semiativa (Skyhook)'];
    annotation(f,'textbox',[0.05 0.93 0.90 0.055],'String',titulo, ...
        'EdgeColor','none','HorizontalAlignment','center','FontSize',18,'FontWeight','bold');
    m=d.metricas;
    if strcmp(d.nome,'degrau')
        subtitulo='Degrau de 3 cm suavizado por rampa de 20 ms';
        rodape='ATENCAO: N <= 0 previsto na semiativa. Modelo bilateral nao representa separacao pneu-pista.';
        cor=[0.75 0.08 0.08];
    else
        subtitulo=sprintf('RMS da aceleracao: passiva %.3f | semiativa %.3f m/s^2', ...
            m.rms_as_passivo,m.rms_as_semi);
        rodape='Resultados numericos; parametros preliminares. Visualizacao esquematica, sem validacao experimental.';
        cor=[0.2 0.2 0.2];
    end
    annotation(f,'textbox',[0.05 0.875 0.90 0.05],'String',subtitulo, ...
        'EdgeColor','none','HorizontalAlignment','center','FontSize',12);
    annotation(f,'textbox',[0.02 0.008 0.96 0.05],'String',rodape, ...
        'EdgeColor','none','HorizontalAlignment','center','FontSize',11,'Color',cor);
    annotation(f,'textbox',[0.02 0.10 0.96 0.04], ...
        'String','Reproducao: 0.5x | Escala dos deslocamentos: 4x nos dois paineis | Mesma pista', ...
        'EdgeColor','none','HorizontalAlignment','center','FontSize',11);
    renderizar=getappdata(f,'renderizar_tempo');
    arquivo=fullfile(pasta,['v1_' d.nome '.mp4']); arquivos{k}=arquivo;
    v=VideoWriter(arquivo,'MPEG-4'); v.FrameRate=fps; v.Quality=95; open(v);
    limpezaVideo=onCleanup(@()close(v));
    duracao=d.t(end)/velocidade+2;
    n=round(duracao*fps);
    if strcmp(d.nome,'lombada')
        tPreview=d.parametros.pistas.lombada.t_ini+0.3;
    elseif strcmp(d.nome,'degrau')
        [~,ixPreview]=min(d.N_semi); tPreview=d.t(ixPreview);
    else
        tPreview=4;
    end
    qPreview=round((1+tPreview/velocidade)*fps);
    for q=0:n-1
        t=max(0,min(d.t(end),(q/fps-1)*velocidade));
        renderizar(t); drawnow;
        quadro=getframe(f);
        writeVideo(v,quadro);
        if mod(q,150)==0, fprintf('%s: %d/%d quadros\n',d.nome,q,n); end
        if q==qPreview, imwrite(quadro.cdata,fullfile(pasta,['preview_' d.nome '.png'])); end
    end
    clear limpezaVideo;
    vr=VideoReader(arquivo);
    assert(vr.Width==1280 && vr.Height==720,'Resolucao inesperada.');
    assert(abs(vr.Duration-duracao)<1/fps+1e-3,'Duracao inesperada.');
    assert(abs(vr.FrameRate-fps)<1e-6,'Frame rate inesperado.');
    readFrame(vr); vr.CurrentTime=max(0,vr.Duration-2/fps); readFrame(vr);
    relatorio(k,:)={d.nome,vr.Width,vr.Height,vr.FrameRate,vr.Duration,n};
    fprintf('VIDEO_VERIFICADO: %s | %.2f s\n',arquivo,vr.Duration);
    clear limpezaFigura;
end
T=cell2table(relatorio,'VariableNames',{'cenario','largura','altura','fps','duracao_s','quadros'});
writetable(T,fullfile(pasta,'videos_verificados.csv'));
end
function fechar_figura(f)
if isgraphics(f), close(f); end
end
