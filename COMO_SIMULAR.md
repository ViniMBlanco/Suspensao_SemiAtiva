# Executar a v1

Na raiz do repositorio Suspensao_SemiAtiva, abra SIMULAR_V1.m no MATLAB
e clique em Run (F5).
Escolha Lombada, Senoide ou Degrau. Aguarde o calculo: o diagrama do
Simulink e a animacao comparando as suspensoes passiva e semiativa abrirao.
Na animacao, use Pausar, Reproduzir e Reiniciar para controlar a exibicao.
Execute SIMULAR_V1.m novamente para escolher outra pista.

Os tres cenarios usam modelo/suspensao_semiativa.slx. As entradas sao
definidas em modelo/gerar_pista.m e seus parametros em versoes/v1/parametros.m.

Com a pasta Suspensao_SemiAtiva aberta como Current Folder, tambem pode usar:

```matlab
addpath('modelo','visualizacao')
resultado = simular_cenario('lombada');
% Troque por 'senoide' ou 'degrau'.
```

Para recalcular os tres cenarios e sua validacao de uma vez:

```matlab
[metricas,dados] = main('v1',false);
animar_suspensao(dados(1)); % 1=lombada, 2=senoide, 3=degrau
```

Os graficos ficam em versoes/v1/resultados. No degrau, a forca normal
prevista pode ficar negativa; o modelo de pneu linear deixa de representar
fisicamente o contato nesse trecho.
