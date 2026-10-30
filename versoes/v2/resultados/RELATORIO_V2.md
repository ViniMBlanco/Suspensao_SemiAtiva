# Resultados locais da v2

Pista sintetica baseada na ISO 8608:2016, classe C, 72 km/h (20 m/s). Cinco trechos de 30 s (600 m), sementes 1 a 5. Planta e controle da v1 preservados; c_sky = 3000 N s/m.

## Metodo e criterios

Gd(n)=256e-6*(n/0.1)^(-2) m^3, com n em ciclos/m. 400 bandas logaritmicas de 0.011 a 2.83 ciclos/m; frequencias temporais de 0.22 a 56.6 Hz. Amplitude de cada senoide obtida pela integral exata da PSD na banda. Fases uniformes geradas por RandStream mt19937ar com semente fixa. A mesma fonte de pista alimenta passiva e semiativa.

Subtrai-se apenas a altura inicial, impondo w(0)=0 e fixando a origem vertical. Nao se normaliza o desvio padrao nem se aplica rampa ao perfil. A PSD nao nula em frequencia e a rugosidade permanecem iguais. O veiculo parte do repouso; os primeiros 5 s sao excluidos do RMS principal. Tambem sao registrados os intervalos 0-30 s e 10-30 s.

RMS(a_s)=sqrt(integral(a_s^2 dt)/duracao), integrado por trapz entre 5 e 30 s. Melhora=100*(1-RMS_semi/RMS_passiva). RMS sem ponderacao ISO 2631, usado como indicador comparativo de vibracao, nao como percentual de conforto percebido. Carga dinamica: RMS(N-(m_s+m_u)g). DLC=RMS(carga dinamica)/peso estatico. Picos de aceleracao usam 5-30 s; curso maximo e N minimo consideram o ensaio completo, incluindo a partida.

## Semente de referencia: 1

| Grandeza | Passiva | Semiativa |
|---|---:|---:|
| RMS a_s, 5-30 s [m/s^2] | 1.712519 | 1.359848 |
| Pico absoluto a_s, 5-30 s [m/s^2] | 5.772651 | 3.953797 |
| RMS carga dinamica, 5-30 s [N] | 809.397 | 992.889 |
| DLC, 5-30 s | 0.28451 | 0.34901 |
| Curso maximo, 0-30 s [cm] | 3.2860 | 3.9165 |
| N minimo, 0-30 s [N] | 99.312 | -666.079 |

Reducao de RMS da aceleracao: **20.594%**. Reducao da carga dinamica RMS: -22.670%.

Na semente 1, o RMS da carga dinamica aumentou 22.67% e o curso maximo aumentou 19.19%. Portanto, a reducao de vibracao veio acompanhada de piora nesses dois indicadores.

Sensibilidade a janela: melhora 0-30 s = 20.936%; 5-30 s = 20.594%; 10-30 s = 20.183%.

## Cinco sementes pareadas

| Semente | RMS passiva | RMS semiativa | Reducao [%] | Nmin passiva [N] | Nmin semi [N] |
|---:|---:|---:|---:|---:|---:|
| 1 | 1.712519 | 1.359848 | 20.594 | 99.31 | -666.08 |
| 2 | 1.678654 | 1.362382 | 18.841 | 131.04 | -371.63 |
| 3 | 1.708201 | 1.389555 | 18.654 | 21.77 | -1045.92 |
| 4 | 1.700210 | 1.355999 | 20.245 | -55.51 | -475.54 |
| 5 | 1.651001 | 1.319455 | 20.082 | -331.67 | -1075.98 |

Media das reducoes pareadas: **19.683%**, desvio entre sementes 0.876 pontos percentuais. Razao das medias dos RMS: reducao 19.683%. Sao estatisticas diferentes; nenhuma e intervalo de confianca.

## Conferencia da pista

Sigma teorico de conjunto = 15.226 mm. Desvios medidos nos cinco trechos = 13.339 15.384 16.413 12.513 17.274 mm.

Um trecho finito pode diferir do sigma de conjunto por conter poucos ciclos longos. A classe alvo e definida pelos coeficientes espectrais, nao por forcar sigma=15.2 mm. PSD_pista.csv e pista_e_PSD_v2.png apresentam o periodograma unilateral espacial, com detrend linear, janela Hann, agrupamento em 24 bandas log e media das cinco sementes. A faixa 0.03-1.5 ciclos/m e usada para estimar Gd0 e inclinacao; conferencia_classe_C.csv contem os valores. Estimativa finita nao e certificacao normativa de pista medida.

## Interpretacao e limites

A corrente da bobina atingiu 1.5767 A na semente 1, excedendo a referencia maxima de 1.50 A em 0.0767 A. O modelo limita a referencia de corrente, a tensao do driver e o amortecimento, mas nao impoe um limitador ideal na corrente real da bobina. Trata-se de sobre-elevacao dinamica da malha original, que merece verificacao do atuador. O parametro e a estrutura da v1 foram preservados, sem adicionar um limitador artificial.

**Houve N <= 0 em pelo menos um ensaio.** O pneu linear bilateral nao modela voo e recontato. As metricas desses ensaios sao resultados do modelo linear, com limitacao fisica apos a primeira perda de contato. Nao se deve ocultar o fato nem afirmar aderencia validada. metricas_sementes.csv informa duracoes e Nmin.

| Semente | Primeiro N<=0 passivo [s] | Primeiro N<=0 semi [s] | Tempo N<=0 passivo [s] | Tempo N<=0 semi [s] |
|---:|---:|---:|---:|---:|
| 1 | NaN | 3.1340 | 0.0000 | 0.0470 |
| 2 | NaN | 1.1600 | 0.0000 | 0.0585 |
| 3 | NaN | 8.8075 | 0.0000 | 0.0745 |
| 4 | 20.4570 | 5.7440 | 0.0040 | 0.0605 |
| 5 | 9.7650 | 0.2615 | 0.0145 | 0.1015 |

NaN significa que nao houve N<=0. Duracao obtida por trapz do indicador N<=0 na malha de 0.5 ms.

A reducao de RMS representa menor vibracao media quadratica; as curvas podem se cruzar e os picos nao precisam cair na mesma proporcao. Avaliar simultaneamente carga dinamica e curso evita escolher um controle apenas pelo conforto. O ganho 3000 e o da v1, sem otimizacao nesta etapa. A comparacao nao comprova desempenho em toda pista classe C, outras velocidades ou veiculo real.

## Verificacao

Testes aprovados: parametros fisicos e de controle iguais aos da v1, fases reprodutiveis, RNG global preservado, energia exata das bandas, uma unica fonte de pista, passividade, limites de c e tensao, equacoes mecanicas e comparacao com integracao RK4 independente do ramo passivo.

Erro maximo dos estados passivos contra RK4 = 1.72e-13. Com dt/2, RMS mudou 0.00630% (passiva) e 0.00598% (semiativa).

## Entregas e escopo

Modelo executavel: ../suspensao_semiativa_v2.slx. Fontes em modelo/, visualizacao/, testes/ e ../parametros.m. Graficos PNG e FIG editaveis, CSV de metricas, perfil e PSD e MAT de sinais completos. varrer_ganhos_v2.m esta preparado para a etapa seguinte, sem mudar os parametros da v2. Os scripts executam localmente; publicacao e tags sao feitas separadamente pelo Git. Sinais MAT e figuras FIG sao regeneraveis e nao sao versionados.

## Referencias e requisitos fornecidos

- Cronograma_Projeto_Suspensao.pdf, secao 4.2, tarefas da semana 2.
- Resumo_ISO8608_ClasseC_72kmh.pdf, equacoes 1 a 4 e Quadro 2, 28/10/2026.
- ISO 8608:2016: https://www.iso.org/standard/71202.html
- Diaz-Choque et al. (2021), secao 6.1: https://doi.org/10.1155/2021/8084343
- Agostinacchio et al. (2014): https://doi.org/10.1007/s12544-013-0127-8

Resumo agregado adicional: 10 indicadores em resumo_cinco_sementes.csv.
