%% V2: mesma planta e controle da v1, pista sintetica ISO 8608 classe C.
run(fullfile(fileparts(mfilename('fullpath')),'..','v1','parametros.m'));
versao='v2';
pistas=struct;
pistas.iso8608=struct('t_final',30,'t_metrica',5,'Gd0',256e-6, ...
    'n0',0.1,'n_min',0.011,'n_max',2.83,'N',400,'V',20,'semente',1);
visual.velocidade_mapa=20; % Nesta versao coincide com a velocidade do ensaio.
pista_tipo='iso8608';
[pista,t_final,t_metrica]=gerar_pista(pista_tipo,pistas,dt);
