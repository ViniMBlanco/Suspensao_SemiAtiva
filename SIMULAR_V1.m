% Abra este arquivo no MATLAB e clique em Run (F5).
% Funciona diretamente a partir de uma copia clonada deste repositorio.
raiz = fileparts(mfilename('fullpath'));
cd(raiz);
addpath(fullfile(raiz,'modelo'),fullfile(raiz,'visualizacao'));
opcao = menu('Simulacao v1 - escolha a pista','Lombada','Senoide','Degrau');
if opcao > 0
    cenarios = {'lombada','senoide','degrau'};
    resultado = simular_cenario(cenarios{opcao});
end
