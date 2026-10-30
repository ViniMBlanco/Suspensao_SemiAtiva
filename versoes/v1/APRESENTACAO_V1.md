# Notas para apresentar a v1

## O que o diagrama representa

A saida da valvula e o coeficiente de amortecimento c(t), em N.s/m.
A perturbacao w(t) e o deslocamento da estrada, em m. Nao se somam
esses sinais: sao entradas de naturezas diferentes da planta quarter-car.

Dentro da planta, o amortecedor produz Fd = c(t)*(vs-vu). As equacoes sao:

    ms*as = -ks*(zs-zu) - Fd
    mu*au =  ks*(zs-zu) + Fd - kt*(zu-w)

Portanto, ha somas de FORCAS nas equacoes mecanicas. Para mostrar uma
perturbacao somada externamente como forca, seria necessario converter
w em kt*w e aplicar essa forca na equacao da massa nao suspensa, mantendo
os demais termos. Somar w diretamente com c seria dimensionalmente errado.
Os subsistemas do diagrama atual agrupam essas equacoes; elas podem ser
examinadas com duplo clique.

A malha interna tem um somador explicito: e_i[k] = i_ref[k] - i[k].
O Skyhook externo e uma lei de amortecimento baseada em vs e vs-vu,
e nao um controlador de erro de aceleracao. O objetivo de regulacao e
reduzir o movimento da carroceria, com referencia de movimento nulo.

E possivel desenhar uma referencia de velocidade zero e e_v=0-vs.
Nesse caso a forca ideal sobre a carroceria seria F_sky*=c_sky*e_v,
e o mapa para o amortecimento semiativo teria de preservar o sinal e a
restricao dissipativa. Nao se deve simplesmente inserir 0-as na entrada
do Skyhook existente: isso mudaria o significado e as unidades do controle.

## O que a v1 entrega

O README original da v1 (commit 4f6115f) define a primeira implementacao
com os parametros da S1, arquitetura completa e comparacao passiva x
semiativa em lombada, senoide e degrau. Esse escopo foi implementado,
executado e verificado numericamente. Ha modelo editavel, sensores,
estimador, Skyhook, PI digital, saturacao/antiwindup, ZOH, bobina RL,
valvula, graficos, metricas e animacao com os sinais calculados.

A v1 nao encerra os objetivos do projeto completo do README principal:
ficam para etapas seguintes pista ISO 8608, RMS ponderado ISO 2631,
varredura de ganhos/limites e estudo sistematico de robustez variando
o atraso da valvula e o periodo de amostragem. Testar dt/2 verifica
convergencia numerica; nao substitui esse estudo de robustez.

Nao foi fornecida uma rubrica independente do professor. A avaliacao de
completude acima e relativa ao escopo documentado no repositorio.

## Resultados e limites a mencionar

- Lombada: RMS de aceleracao cai aproximadamente 15,93%.
- Senoide: RMS de aceleracao cai aproximadamente 2,90%.
- Degrau: a semiativa preve N_min de aproximadamente -485 N. O pneu
  linear bilateral nao representa separacao pneu-pista; a resposta apos
  N<=0 nao comprova desempenho fisico. Curso e carga dinamica pioram
  nesse cenario. Nao apresentar a reducao de RMS como beneficio validado.
- Os parametros sao preliminares, com hipoteses explicitadas na v1;
  os testes verificam a implementacao, sem validacao experimental.

## Videos

Arquivos em resultados/videos: v1_lombada.mp4, v1_senoide.mp4,
v1_degrau.mp4. Exportacao quadro a quadro dos dados do Simulink,
sem dependencia da velocidade de renderizacao da maquina: 1280x720,
30 fps, reproducao a 0,5x e ampliacao de deslocamento de 4x igual nos
dois paineis. O primeiro e o ultimo estado permanecem por cerca de 1 s.
A escala da geometria e esquematica; a conversao tempo-distancia da
estrada e apenas visual e nao define uma velocidade de veiculo medida.
O degrau contem aviso persistente da limitacao de contato.

Para regenerar os videos no MATLAB, a partir da raiz do repositorio:

```matlab
addpath('visualizacao');
exportar_videos_v1;
```
