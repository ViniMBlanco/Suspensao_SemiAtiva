%% Execute este arquivo pelo botao Run. Abre o modelo e os graficos da v2.
raiz_v2=fileparts(mfilename('fullpath'));
addpath(fullfile(raiz_v2,'modelo'),fullfile(raiz_v2,'visualizacao'),fullfile(raiz_v2,'testes'));
[metricas_v2,dados_v2]=executar_v2;
open_system(fullfile(raiz_v2,'versoes','v2','suspensao_semiativa_v2.slx'));
openfig(fullfile(raiz_v2,'versoes','v2','resultados','comparacao_v2.fig'),'visible');
% Opcional, para assistir a animacao calculada: animar_suspensao(dados_v2(1));
