%% V3: ajuste final da campanha com o pneu linear da V2.
pasta_v3 = fileparts(mfilename('fullpath'));
run(fullfile(pasta_v3, '..', 'v1', 'parametros.m'));
lombada_v3 = pistas.lombada;
run(fullfile(pasta_v3, '..', 'v2', 'parametros.m'));
versao = 'v3';
c_sky = 4000;          % [N.s/m] compromisso de conforto e carga dinâmica
pistas.lombada = lombada_v3;
clear pasta_v3 lombada_v3
