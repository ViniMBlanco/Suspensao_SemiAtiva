function in=entrada_v2(cfg,pista)
% Parametros explicitos por execucao; nao grava alteracoes no .slx.
in=Simulink.SimulationInput('suspensao_semiativa_v2');
nomes=fieldnames(cfg);
for k=1:numel(nomes), in=in.setVariable(nomes{k},cfg.(nomes{k})); end
in=in.setVariable('pista',pista);
in=in.setVariable('t_final',pista(end,1));
end
