# V2 - pista irregular ISO 8608 classe C a 72 km/h

Entrega da semana 2 do cronograma. A planta, os sensores, o PI, a bobina, a valvula e o ganho Skyhook da v1 foram mantidos. A mudanca do ensaio e a pista sintetica irregular. O modelo executavel, fontes, resultados, grafico comparativo e video fazem parte desta entrega.

## Executar e visualizar no MATLAB

Na pasta raiz do projeto, abra **SIMULAR_V2.m** e clique em **Run**. O script executa os cinco trechos, confere os resultados e abre o diagrama executavel e o grafico comparativo. Tambem e possivel usar:

```matlab
addpath('modelo','visualizacao','testes');
[T,dados] = executar_v2;
open_system(fullfile(pwd,'versoes','v2','suspensao_semiativa_v2.slx'));
animar_suspensao(dados(1)); % opcional: animacao do trecho de referencia
```

Para abrir o modelo existente sem repetir os cinco ensaios, de duplo clique em **suspensao_semiativa_v2.slx** nesta pasta. Ele carrega automaticamente os parametros da v2 e a pista da semente 1. Clique em **Run** no Simulink. Os sinais da execucao ficam em `out`; o botao Run sozinho nao atualiza os CSV e graficos de resultados.

Para ver o grafico entregue sem simular, abra [a imagem comparativa](resultados/comparacao_aceleracoes/aceleracao_iso8608.png). O [video MP4](resultados/videos/v2_iso8608_classeC_72kmh.mp4) tambem esta incluido.

As figuras editaveis FIG e os sinais completos MAT sao gerados localmente e nao sao versionados. Depois de executar `SIMULAR_V2.m`, e possivel reabrir a figura e a animacao sem repetir as simulacoes:

```matlab
openfig(fullfile(pwd,'versoes','v2','resultados','comparacao_v2.fig'),'visible');
a = load(fullfile(pwd,'versoes','v2','resultados','dados_simulacao.mat'));
animar_suspensao(a.dados(1));
```

Requer MATLAB + Simulink. As rotinas de PSD utilizam FFT e janela Hann implementada no codigo, sem exigir Signal Processing Toolbox.

## Configuracao

| Item | Valor |
|---|---|
| Classe / PSD de referencia | C / Gd(0.1) = 256e-6 m^3 |
| Convencao espacial | ciclos/m; PSD unilateral |
| Velocidade | 20 m/s = 72 km/h |
| Faixa espacial | 0.011 a 2.83 ciclos/m |
| Faixa temporal | 0.22 a 56.6 Hz |
| Sintese | 400 bandas logaritmicas, energia integrada exata |
| Fases | mt19937ar; sementes 1, 2, 3, 4, 5 |
| Trecho de referencia | semente 1 |
| Duracao / distancia | 30 s / 600 m por semente |
| Solver / passo | ode4 / 0.0005 s |
| Amostragem do controle | 0.001 s |
| Ganho Skyhook | 3000 N s/m, igual a v1 |
| Amortecimento passivo | 1500 N s/m, igual a v1 |
| Janela principal das metricas RMS | 5 a 30 s |

`parametros.m` herda os parametros da v1 e define somente a pista da v2 e sua velocidade de desenho. `gerar_pista.m` usa a equacao de soma de senoides fornecida no resumo. Subtrai-se apenas a altura inicial para compatibilizar a origem vertical com o veiculo em repouso; nao se altera a escala da rugosidade.

## Resultados e verificacao

Consulte **resultados/RELATORIO_V2.md** para numeros, interpretacao e limites. Os arquivos incluem:

- `metricas.csv`: semente 1; `metricas_sementes.csv`: cinco ensaios pareados.
- `resumo_cinco_sementes.csv`: media e desvio entre trechos.
- `comparacao_v2.png` e `.fig`: aceleracao, RMS, carga no pneu e curso.
- `controle_v2.png` e `.fig`: corrente, tensao, amortecimento e potencia dissipada.
- `pista_e_PSD_v2.png` e `.fig`, `PSD_pista.csv`, `conferencia_classe_C.csv`: verificacao da pista.
- `perfil_iso8608_semente1.csv`: perfil com tempo, distancia e altura.
- `dados_simulacao.mat`: sinais completos das cinco sementes, regenerados localmente.
- `validacao.csv`, `convergencia_numerica.csv`: equacoes, passividade, contato e teste com dt/2.
- `diagrama_v2.png`: diagrama exportado do modelo executavel.

O RMS da aceleracao e nao ponderado. Nao equivale a avaliacao normativa ISO 2631. A PSD e o desvio padrao medidos em 600 m variam com as fases; o sigma teorico de 15.2 mm e um valor de conjunto, nao uma meta para reescalar cada trecho.

O pneu e linear bilateral. Se N <= 0, a perda de contato e sinalizada e a interpretacao fisica fica limitada; nao se recortam os dados nem se muda a pista para esconder esse efeito.

## Grafico no formato da v1 e video

Para gerar novamente a figura com resposta completa, zoom temporal e barras de RMS com percentual:

```matlab
plotar_comparacao_aceleracoes('v2',false);
```

A semente de referencia e a 1. A imagem fica em `resultados/comparacao_aceleracoes/aceleracao_iso8608.png`, com copia editavel `.fig` e copia JPEG `resultados/v2_iso8608.jpeg`.

Para gravar a animacao a partir dos sinais ja calculados:

```matlab
exportar_video_v2;
```

O MP4 fica em `resultados/videos/v2_iso8608_classeC_72kmh.mp4`: 1280x720, 30 fps, 62 s, reproducao 0.5x e deslocamentos ampliados 4x igualmente nos dois paineis. O video informa a limitacao de contato do pneu linear. Nao sao executadas novas simulacoes para gerar essas midias.

## Inicio da proxima etapa

`modelo/varrer_ganhos_v2.m` prepara a varredura de 10 ganhos Skyhook e 10 amortecimentos passivos de 600 a 2400 N s/m, sempre na mesma pista. Salva os resultados em uma subpasta separada e nao modifica `parametros.m` ou o `.slx`. A execucao oficial da v2 **nao escolhe um ganho final**; essa tarefa pertence a semana 3.

```matlab
Tganhos = varrer_ganhos_v2;
```

## Base documental

- Cronograma fornecido, secao 4.2, semana 2: pista ISO, v2, comparacao e inicio do script de varredura.
- Resumo fornecido, Quadro 2 e equacoes 1-4: classe C, 72 km/h, 400 bandas e 30 s.
- [Cronograma do grupo](../../docs/Cronograma_Projeto_Suspensao.pdf).
- [Resumo da pista classe C a 72 km/h](../../docs/Resumo_ISO8608_ClasseC_72kmh.pdf).
- [ISO 8608:2016](https://www.iso.org/standard/71202.html).
- [Diaz-Choque et al. (2021), secao 6.1](https://doi.org/10.1155/2021/8084343).
- [Agostinacchio et al. (2014)](https://doi.org/10.1007/s12544-013-0127-8).
