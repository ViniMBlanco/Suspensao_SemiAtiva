# V3 · Suspensão semiativa no Simulink

A V3 usa `c_sky = 4000 N·s/m`, período de amostragem de 1 ms e constante de tempo da válvula de 15 ms. A referência é a suspensão passiva com `c_pass = 1500 N·s/m`. A planta de ¼ de veículo mantém o pneu linear bilateral. A saturação do amortecimento efetivo permanece entre 600 e 2400 N·s/m. [Parâmetros](parametros.m) · [Modelo SLX](suspensao_semiativa_v3.slx) · [Diagrama do modelo](resultados/diagrama_v3.png)

## Escolha do ganho

A varredura no Simulink R2024b comparou dez ganhos skyhook, dez amortecimentos passivos de 600 a 2400 N·s/m e a referência passiva adicional de 1500 N·s/m, nas mesmas cinco sementes. O ganho 4000 preserva boa parte da redução de aceleração de 3000 e reduz o aumento de carga dinâmica. Os ganhos de 6000 e 8000 reduzem mais esse aumento, com menor benefício de conforto. [Curva conforto × aderência](resultados/simulink_v3/conforto_aderencia.png) · [Varredura agregada](resultados/simulink_v3/varredura_media.csv) · [Varredura por semente](resultados/simulink_v3/varredura_por_semente.csv)

| Ganho skyhook [N·s/m] | Variação da aceleração RMS | Variação da carga dinâmica RMS | Pior força normal calculada [N] |
|---:|---:|---:|---:|
| 2000 | −20,01% | +26,62% | −1168,5 |
| 3000 | −19,68% | +23,13% | −1076,0 |
| 4000 | −18,75% | +20,45% | −1018,3 |
| 6000 | −16,31% | +16,40% | −916,4 |
| 8000 | −13,91% | +13,21% | −811,1 |

Nenhum ganho testado manteve força normal positiva em todas as pistas. A força normal calculada também foi não positiva em dois dos cinco trechos da passiva de referência. O pneu bilateral ainda transfere força nesses intervalos. A carga dinâmica RMS é, portanto, um indicador do comportamento simulado. A aderência física sob perda e retomada de contato requer uma nova campanha com pneu unilateral.

## Resultados nominais no Simulink

| Cenário | Aceleração RMS passiva / semiativa [m/s²] | Variação | Carga dinâmica RMS passiva / semiativa [N] | Variação | Trechos com N ≤ 0 passiva / semiativa |
|---|---:|---:|---:|---:|---:|
| Lombada de 5 cm | 0,572 / 0,478 | −16,44% | 151,0 / 128,2 | −15,08% | 0/1 · 0/1 |
| ISO 8608 classe C a 72 km/h | 1,690 / 1,373 | −18,75% | 802,2 / 966,3 | +20,45% | 2/5 · 5/5 |

As janelas de RMS são 1–8 s na lombada e 5–30 s na ISO. O mínimo da força normal usa a simulação inteira. As variações na ISO usam a razão entre as médias dos RMS das cinco sementes. A coluna `melhora_media_por_ensaio_pct` do CSV faz a média dos percentuais individuais. O pico de corrente real na ISO foi 1,577 A, com a referência limitada a 1,5 A. [Comparação](resultados/simulink_v3/tabela_comparativa.csv) · [Métricas por ensaio](resultados/simulink_v3/metricas_por_ensaio.csv) · [Lombada](resultados/simulink_v3/lombada.png) · [Pista ISO, semente 1](resultados/simulink_v3/iso8608_semente1.png)

## Robustez no Simulink

As nove combinações de amostragem e válvula foram avaliadas nas mesmas cinco sementes, com ganho 4000 e passo fixo do solver de 0,5 ms. O período medido na saída amostrada foi conferido e as matrizes do estimador foram recalculadas para cada período. A coluna de contato conta quantas das cinco pistas tiveram pelo menos uma ocorrência de N ≤ 0. [Resumo](resultados/simulink_v3/robustez_resumo.csv) · [45 registros por combinação e semente](resultados/simulink_v3/robustez_por_semente.csv)

| Amostragem [ms] | Constante da válvula [ms] | Variação da aceleração RMS | Variação da carga dinâmica RMS | Trechos semiativos com N ≤ 0 |
|---:|---:|---:|---:|---:|
| 0,5 | 7,5 | −21,80% | +24,28% | 5/5 |
| 0,5 | 15,0 | −18,84% | +20,53% | 5/5 |
| 0,5 | 30,0 | −15,84% | +17,67% | 5/5 |
| 1,0 | 7,5 | −21,69% | +24,23% | 5/5 |
| 1,0 | 15,0 | −18,75% | +20,45% | 5/5 |
| 1,0 | 30,0 | −15,72% | +17,54% | 5/5 |
| 2,0 | 7,5 | −21,44% | +24,17% | 5/5 |
| 2,0 | 15,0 | −18,38% | +20,23% | 5/5 |
| 2,0 | 30,0 | −15,48% | +17,39% | 5/5 |

A reprodução da primeira semente da V2 usa os parâmetros históricos na topologia comum. A convergência compara 0,5 e 0,25 ms para a lombada e a primeira pista ISO no ajuste nominal. [Validação](resultados/simulink_v3/validacao.csv) · [Referência e convergência](resultados/simulink_v3/convergencia_e_referencia.csv)

## Reprodução e histórico

Em uma sessão nova do MATLAB R2024b com Simulink, abra [SIMULAR_V3.m](../../SIMULAR_V3.m) e clique em **Run**. O modelo também pode ser aberto diretamente para rodar a primeira pista ISO. Os arquivos da campanha são exportados em `resultados/simulink_v3/`. Para experimentar outro ganho, adicione `modelo` ao path e chame `executar_v3_simulink(ganho)`. Os resultados alternativos são gravados em uma subpasta local.

O caso exploratório anterior usou 8000 N·s/m. Os resultados históricos continuam disponíveis para comparação, com a sensibilidade em Python variando um fator por vez. Para reproduzir o estudo independente, execute `python -B modelo/simular_v3.py` com NumPy 2, Matplotlib e um compilador C acessível como `cc`. [Resultados Python](resultados/tabela_comparativa.csv) · [Sensibilidade Python](resultados/sensibilidade_resumo.csv) · [Conferência histórica no Simulink](resultados/simulink/tabela_comparativa.csv) · [Testes do integrador independente](resultados/verificacao.txt)
