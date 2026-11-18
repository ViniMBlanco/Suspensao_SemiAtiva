%% V3 exploratória: lombada, cinco pistas ISO e varredura conforto × aderência
% Abra este arquivo no MATLAB e clique em Run.
% O ganho de 8000 N·s/m representa o caso de diagnóstico documentado.
% Use uma sessão nova, pois os scripts do modelo carregam parâmetros no workspace base.
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'modelo'));
T = executar_v3_simulink(8000);
