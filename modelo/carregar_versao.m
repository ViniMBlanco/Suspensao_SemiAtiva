function cfg = carregar_versao(versao)
% Carrega o script da versao e devolve um retrato dos parametros utilizados.
assert(ischar(versao)||isstring(versao),'Versao deve ser um nome, por exemplo v1.');
versao=char(versao);
assert(~isempty(regexp(versao,'^[A-Za-z0-9_-]+$','once')),'Nome de versao invalido.');
raiz=fileparts(fileparts(mfilename('fullpath')));
arquivo=fullfile(raiz,'versoes',versao,'parametros.m');
assert(isfile(arquivo),'Arquivo de parametros nao encontrado: %s',arquivo);
evalin('base',sprintf('run(''%s'');',strrep(arquivo,'''','''''')));
nomes={'versao','dt','Ts','m_s','m_u','k_s','k_t','g','c_pass','c_min','c_max', ...
 'K_ci','i_max','tau_v','c_inicial','i0','R','L','V_min','V_max','Kp','Ki', ...
 'c_sky','v_eps','usar_sensores','w_fuga','A_sd','B_sd','C_sd','D_sd', ...
 'A_p','B_p','C_p','D_p','K_ext','bias_ext','K_vrel','pistas','visual'};
for k=1:numel(nomes), cfg.(nomes{k})=evalin('base',nomes{k}); end
assert(cfg.dt>0 && cfg.Ts>0 && abs(cfg.Ts/cfg.dt-round(cfg.Ts/cfg.dt))<1e-10);
assert(cfg.c_min>=0 && cfg.c_max>cfg.c_min && cfg.R>0 && cfg.L>0 && cfg.tau_v>0);
end
