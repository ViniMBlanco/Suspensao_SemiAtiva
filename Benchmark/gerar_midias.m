function gerar_midias(soGraficos)
% Usa os mesmos renderizadores MATLAB da V1 e da V2, com os sinais do benchmark.
if nargin<1, soGraficos=false; end
pasta=fileparts(mfilename('fullpath'));
addpath(fullfile(fileparts(pasta),'visualizacao'));
temporaria=tempname;
mkdir(temporaria);
limpeza=onCleanup(@()rmdir(temporaria,'s'));
metricas=readtable(fullfile(pasta,'resultados','metricas.csv'),'TextType','string');
d(1)=cenario(pasta,temporaria,metricas,'lombada',0,1,10,[.7 4.3], ...
    'Benchmark | Lombada de 5 cm','comparacao.png');
d(2)=cenario(pasta,temporaria,metricas,'iso8608',5,5,20,[5 9], ...
    'Benchmark | ISO 8608 classe C | 72 km/h | Semente 5','comparacao_iso8608.png');
plotar_comparacao_aceleracoes('Benchmark',false,d);
if soGraficos, return; end

fps=30;
arquivo=fullfile(temporaria,'comparacao.mp4');
v=VideoWriter(arquivo,'MPEG-4');
v.FrameRate=fps;
v.Quality=95;
open(v);
fecharvideo=onCleanup(@()close(v));
quadros=gravar(v,d(1),.5,fps,'');
quadros=quadros+gravar(v,d(2),.25,fps,fullfile(pasta,'quadro_animacao.png'));
clear fecharvideo
vr=VideoReader(arquivo);
assert(vr.Width==1280 && vr.Height==720 && abs(vr.FrameRate-fps)<1e-6);
assert(abs(vr.Duration-quadros/fps)<1/fps+1e-3);
readFrame(vr);
vr.CurrentTime=vr.Duration-2/fps;
readFrame(vr);
fprintf('BENCHMARK_VIDEO_OK | %.2f s | %d quadros | %d x %d\n', ...
    vr.Duration,quadros,vr.Width,vr.Height);
clear vr
movefile(arquivo,fullfile(pasta,'comparacao.mp4'),'f');
end

function d=cenario(pasta,temporaria,metricas,nome,semente,inicio,velocidade,zoom,titulo,png)
modelos=["V3","CDC"];
for k=1:2
    nomeArquivo=sprintf('sinais_%s_%d_%s.csv.gz',nome,semente,modelos(k));
    descompactado=gunzip(fullfile(pasta,'resultados',nomeArquivo),temporaria);
    sinais{k}=readtable(descompactado{1}); %#ok<AGROW>
    linha=metricas(metricas.cenario==nome & metricas.semente==semente & ...
        metricas.modelo==modelos(k) & metricas.tau_ms==15,:);
    assert(height(linha)==1);
    rms(k)=linha.rms_aceleracao_m_s2; %#ok<AGROW>
end
a=sinais{1}; b=sinais{2};
assert(isequal(a.tempo_s,b.tempo_s) && isequal(a.pista_m,b.pista_m));
z=zeros(height(a),1);
% Layout comum de coletar_sinais: [pista, 5 estados/saídas por suspensão, ...].
d.y=[a.pista_m,a.carroceria_m,z,a.roda_m,z,a.aceleracao_m_s2,...
    b.carroceria_m,z,b.roda_m,z,b.aceleracao_m_s2,z,z];
d.t=a.tempo_s;
d.N_pass=a.normal_N;
d.N_semi=b.normal_N;
d.t_metrica=inicio;
d.nome=nome;
d.visual=struct('escala',4,'velocidade_mapa',velocidade,'fps',30,'reproducao',.5);
d.parametros.c_pass=1500;
d.benchmark=struct('titulo',titulo,'zoom',zoom,'png',png,'rms',rms, ...
    'forca',[a.forca_amortecedor_N,b.forca_amortecedor_N]);
end

function n=gravar(v,d,velocidade,fps,print)
f=animar_suspensao(d,true);
fechar=onCleanup(@()close(f));
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
nota(f,[.03 .93 .94 .055],d.benchmark.titulo,18);
nota(f,[.03 .875 .94 .05],sprintf('Aceleracao RMS da carroceria: V3 %.3f m/s^2 | CDC %.3f m/s^2', ...
    d.benchmark.rms(1),d.benchmark.rms(2)),12);
nota(f,[.02 .10 .96 .04],sprintf('Reproducao %.2fx | Mesma pista | Mesmo Skyhook de 4.000 N s/m',velocidade),11);
nota(f,[.02 .005 .96 .052], ...
    'Pneu unilateral. O modelo CDC usa curvas de bancada com o controle da V3.',11);
renderizar=getappdata(f,'renderizar_tempo');
inicio=d.benchmark.zoom(1);
fim=d.benchmark.zoom(2);
n=round((fim-inicio)*fps/velocidade);
for q=0:n-1
    renderizar(inicio+q*velocidade/fps);
    drawnow;
    quadro=getframe(f);
    writeVideo(v,quadro);
    if mod(q,150)==0
        fprintf('BENCHMARK_VIDEO %s | %d/%d quadros\n',d.nome,q,n);
    end
end
if ~isempty(print)
    primeiro=find(d.t>=inicio & d.t<=fim & d.N_pass==0,1);
    assert(~isempty(primeiro),'O recorte ISO precisa incluir uma perda de contato.');
    renderizar(d.t(primeiro));
    drawnow;
    quadro=getframe(f);
    imwrite(quadro.cdata,print);
end
end

function nota(f,pos,texto,tamanho)
annotation(f,'textbox',pos,'String',texto,'EdgeColor','none', ...
    'HorizontalAlignment','center','FontSize',tamanho,'Color',[.1 .1 .1]);
end
