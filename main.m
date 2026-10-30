function [T,dados] = main(versao, animar)
% MAIN Executa a versao, valida os resultados e abre a animacao comparativa.
%   main                  % v1, tres pistas e animacao da lombada
%   main('v1',false)      % execucao sem janela de animacao
if nargin<1, versao='v1'; end
if nargin<2, animar=true; end
raiz=fileparts(mfilename('fullpath'));
addpath(fullfile(raiz,'modelo'),fullfile(raiz,'visualizacao'),fullfile(raiz,'testes'));
if strcmp(versao,'v2')
 [T,dados]=executar_v2;
 if animar
  open_system(fullfile(raiz,'versoes','v2','suspensao_semiativa_v2.slx'));
  animar_suspensao(dados(1));
 end
 return;
end
carregar_versao(versao);
montar_modelo(false);
[T,dados]=rodar_versao(versao);
validar_v1(dados);
if animar
 open_system(fullfile(raiz,'modelo','suspensao_semiativa.slx'));
 animar_suspensao(dados(1));
end
end
