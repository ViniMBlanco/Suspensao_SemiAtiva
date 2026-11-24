function in=entrada_v2(cfg,pista,modelo)
% Parametros explicitos por execucao; nao grava alteracoes no .slx.
if nargin < 3, modelo = 'suspensao_semiativa_v2'; end
in=Simulink.SimulationInput(modelo);
nomes=fieldnames(cfg);
for k=1:numel(nomes), in=in.setVariable(nomes{k},cfg.(nomes{k})); end
in=in.setVariable('pista',pista);
in=in.setVariable('t_final',pista(end,1));
end
