# V3 · Resultados de conforto e aderência

A reprodução numérica preserva a planta de ¼ de veículo, o skyhook com velocidades estimadas, a bobina, a válvula e a retenção do comando. Ela usa RK4 com passo de 0,5 ms e atualiza o controle a cada 1 ms. O PI trapezoidal e o bloqueio da integração seguem uma implementação independente. A referência é o repositório da equipe no commit [2192059](https://github.com/ViniMBlanco/Suspensao_SemiAtiva/tree/219205969b1a231a3d5bd2322430fa554e5596bc).

## Resultados para o relatório

| Cenário | RMS aceleração passiva / semiativa [m/s²] | Variação | RMS carga dinâmica passiva / semiativa [N] | Variação | Trechos com N ≤ 0 passiva / semiativa |
|---|---:|---:|---:|---:|---:|
| Lombada, 5 cm | 0,572 / 0,477 | −16,49% | 151,0 / 128,9 | −14,64% | 0/1 · 0/1 |
| ISO 8608 classe C, 72 km/h, cinco sementes | 1,690 / 1,457 | −13,82% | 802,2 / 907,5 | +13,13% | 2/5 · 5/5 |

A comparação usa um amortecimento passivo de 1500 N·s/m e um ganho skyhook exploratório de 8000 N·s/m. O ganho de controle pode exceder 2400 N·s/m porque o **amortecimento efetivo** tem uma saturação separada. Os valores ISO acima são médias dos RMS por semente. As variações são calculadas sobre essas médias. As janelas de RMS são de 1–8 s na lombada e 5–30 s na ISO. A força normal mínima usa toda a simulação.

A varredura avalia dez ganhos skyhook e dez amortecimentos passivos nas mesmas cinco pistas. O critério de seleção exige força normal positiva em todas as pistas, carga dinâmica média no máximo igual à passiva de referência e menor RMS de aceleração. Nenhum candidato semiativo passou. O ganho 8000 foi usado para diagnóstico porque apresentou a maior força normal mínima no pior trecho entre os semiativos testados. Ainda assim, a força normal mínima foi −793,5 N. Como 8000 está no extremo superior da grade, o resultado tampouco identifica um ótimo interior.

No modelo atual, o pneu linear bilateral pode produzir força normal negativa e continuar transferindo força para a roda. Os RMS da pista ISO que incluem esses intervalos mostram o compromisso do modelo, mas não sustentam uma conclusão física sobre aderência. A prioridade é introduzir contato unilateral e refazer a seleção antes de congelar o ganho.

## Arquivos

- [Resposta na lombada](resultados/resposta_lombada.png) e [resposta na pista ISO](resultados/resposta_iso8608.png). A pista ISO mostra um recorte da semente 1. O script de reprodução gera os históricos completos desses dois ensaios em arquivos NPZ locais.
- [Conforto × aderência](resultados/conforto_aderencia.png), [varredura por semente](resultados/varredura_por_semente.csv) e [varredura agregada](resultados/varredura_resumo.csv).
- [Tabela comparativa](resultados/tabela_comparativa.csv), [métricas por cenário e semente](resultados/metricas_por_cenario.csv) e [análise de sensibilidade](resultados/sensibilidade_resumo.csv).
- [Registro dos testes locais](resultados/verificacao.txt). A pista da semente 1 corresponde ao CSV publicado. Os RMS passivos coincidem com a referência. Nos RMS semiativos do cenário V2, a maior diferença frente ao registro histórico de MATLAB foi de 0,31% nas cinco sementes. Nos cenários publicados aqui, reduzir o passo de 0,5 para 0,25 ms manteve o diagnóstico de contato e alterou as métricas verificadas em menos de 0,10%.

## Conferência no Simulink R2024b

A campanha executou [`SIMULAR_V3.m`](../../SIMULAR_V3.m) com o modelo V2 da revisão [`437b507`](https://github.com/ViniMBlanco/Suspensao_SemiAtiva/tree/437b507e2898ed87fff5f324301ecbcb8999c875). A comparação usa `c_sky = 8000 N·s/m` e `c_pass = 1500 N·s/m`.

| Cenário | Variação no RMS da aceleração | Variação no RMS da carga dinâmica | Trechos com N ≤ 0 passiva / semiativa |
|---|---:|---:|---:|
| Lombada de 5 cm | −16,51% | −14,66% | 0/1 · 0/1 |
| ISO 8608 classe C a 72 km/h, cinco sementes | −13,91% | +13,21% | 2/5 · 5/5 |

Os percentuais da tabela usam as médias dos RMS por semente, como na comparação do integrador independente. A coluna `melhora_media_por_ensaio_pct` do CSV nativo usa a média das melhorias individuais. A varredura nativa inclui os mesmos dez ganhos semiativos e acrescenta a referência de 1500 N·s/m à grade de dez amortecimentos passivos.

Nenhum ganho semiativo manteve força normal positiva nas cinco pistas. Com 8000 N·s/m, a menor força normal calculada foi −811,1 N. A corrente real atingiu 1,577 A na ISO, com referência limitada a 1,5 A. O ganho final depende de uma nova varredura com contato unilateral.

A reprodução da semente 1 da V2 coincidiu com o RMS histórico da aceleração dentro da precisão numérica. Reduzir o passo de 0,5 para 0,25 ms mudou esse RMS em menos de 0,007% na lombada e na primeira pista ISO.

- [Tabela comparativa](resultados/simulink/tabela_comparativa.csv) e [métricas por ensaio](resultados/simulink/metricas_por_ensaio.csv).
- [Varredura por semente](resultados/simulink/varredura_por_semente.csv), [varredura agregada](resultados/simulink/varredura_media.csv) e [curva conforto × aderência](resultados/simulink/conforto_aderencia.png).
- [Resposta na lombada](resultados/simulink/lombada.png), [resposta na pista ISO, semente 1](resultados/simulink/iso8608_semente1.png), [validação dos ensaios](resultados/simulink/validacao.csv) e [verificação de referência e convergência](resultados/simulink/convergencia_e_referencia.csv).

## Reprodução

Na raiz do repositório, execute `python -B modelo/simular_v3.py` para refazer os resultados e `python -B -m unittest discover -s testes -p testar_v3.py` para executar os testes. A rotina usa Python com NumPy 2 e Matplotlib, além de um compilador C acessível como `cc`.

Para conferir no modelo Simulink do grupo, abra uma sessão nova do MATLAB com Simulink, abra [SIMULAR_V3.m](../../SIMULAR_V3.m) e clique em **Run**. Para testar outro ganho, adicione `modelo` ao path e chame `executar_v3_simulink(ganho)`. A rotina reutiliza o modelo V2 e grava as suas saídas em `versoes/v3/resultados/simulink/`. A criação da tag oficial e a escolha do ganho final dependem da equipe.
