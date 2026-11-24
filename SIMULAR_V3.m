%% V3: lombada, cinco pistas ISO, varredura e robustez no Simulink
% Abra este arquivo no MATLAB e clique em Run.
% Use uma sessão nova, pois os scripts do modelo carregam parâmetros no workspace base.
raiz = fileparts(mfilename('fullpath'));
addpath(fullfile(raiz, 'modelo'));
[T, robustez] = executar_v3_simulink;
