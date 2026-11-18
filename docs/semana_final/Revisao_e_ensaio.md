# Revisão cruzada e ensaio da apresentação

## Entregas da semana final

Neste material, V4 é o nome da pasta de trabalho posterior à V3. O cronograma identifica a V3 como a última versão oficial do modelo. [Cronograma do projeto](https://github.com/ViniMBlanco/Suspensao_SemiAtiva/blob/219205969b1a231a3d5bd2322430fa554e5596bc/docs/Cronograma_Projeto_Suspensao.pdf)

| Data | Atividade | Registro |
|---|---|---|
| 23 e 24/11 | Integrar a seção de implementação no Simulink ao texto do grupo. | Seção editável em [Implementação no Simulink](Implementacao_no_Simulink.md). |
| 25/11 | Montar os slides de implementação e alinhar a transição com a parte de resultados. | [Slides de implementação](Slides_Implementacao_Simulink.pptx). |
| 26/11 | Cada integrante revisa a parte de outro integrante. Fazer um ensaio cronometrado. | Anotar revisor, correções e tempo real. |
| 27/11 | Revisar o relatório e a apresentação como um todo antes da entrega. | Conferir os mesmos valores, cenários e conclusões nos dois arquivos. |

## Pauta para a revisão com o grupo

- [ ] Confirmar o `c_sky` usado na V3, o critério de escolha, o amortecimento passivo de referência e as condições de cada comparação. Para cada semente, registrar `N_min` e a duração em que a força normal estimada ficou não positiva.
- [ ] Conferir a origem de cada resultado e identificar no texto os ensaios executados em Simulink e as verificações numéricas feitas por outro motor. Usar as mesmas unidades e janelas de RMS na tabela e nos slides.
- [ ] Conferir que os gráficos trazem legenda, eixos com unidades e identificação da pista. Na ISO, distinguir o gráfico de uma semente dos resumos das cinco.
- [ ] Separar limite da corrente de referência, pico observado da corrente real, saturação da tensão e faixa do amortecimento efetivo.
- [ ] Ler a seção de implementação junto com resultados e discussão. Verificar que as conclusões conservam as limitações do pneu, do indicador de conforto e da referência comercial.
- [ ] Registrar data, nomes de quem revisou, tempo medido no ensaio e ajustes decididos.

## Roteiro do Murilo

| Tempo sugerido | Fala ou figura |
|---|---|
| 0:00–0:30 | Mostrar os dois ramos do diagrama. A mesma pista excita o modelo passivo e o semiativo, ambos com as mesmas massas e rigidezes. |
| 0:30–1:10 | Seguir o caminho dos sinais. Os acelerômetros alimentam o estimador de velocidade. O skyhook escolhe o amortecimento. O PI, a bobina e a válvula realizam o comando. |
| 1:10–1:40 | Distinguir o período do controlador de 1 ms do passo de integração de 0,5 ms. Apontar a faixa de 600 a 2400 N·s/m e a diferença entre corrente solicitada e corrente real. |
| 1:40–2:00 | Entregar a palavra a quem apresenta os resultados. A comparação vai usar o RMS da aceleração, a carga dinâmica no pneu e a condição de contato. |

O grupo deve registrar os tempos do ensaio em conjunto. Os tempos acima são uma proposta para a parte de implementação.

## Parecer técnico

O quarto de veículo em paralelo com uma referência passiva é adequado ao objetivo acadêmico de comparar a dinâmica vertical sob a mesma entrada. A cascata explicita como a ação digital chega ao amortecedor. Os dados históricos confirmam um ponto importante para a discussão da V3. Um ajuste que melhora o RMS de aceleração pode aumentar a variação de carga no pneu. A coerência da implementação deve ser distinguida da validade física dos ensaios em que o pneu linear prevê força negativa. [Resultados e limitações da V2](https://github.com/ViniMBlanco/Suspensao_SemiAtiva/blob/219205969b1a231a3d5bd2322430fa554e5596bc/versoes/v2/README.md)

| Prioridade | Alteração proposta | Como verificar |
|---|---|---|
| 1 | Representar o pneu com contato unilateral nos dois ramos. Aplicar à dinâmica da roda a força normal `N = max(0, N₀ + k_t(w − z_u))` por meio da contribuição `N − N₀` nas coordenadas em torno do equilíbrio, com `N₀ = (m_s + m_u)g`. | Conferir o equilíbrio estático, a equivalência com o modelo original enquanto houver compressão, a força zero fora do contato e o retorno ao apoio. Repetir a varredura após a mudança. |
| 2 | Se 1,5 A for um limite físico do atuador escolhido, implementar a limitação na dinâmica do acionamento e coordená-la com o anti-windup. A saturação do sinal exibido deixaria o estado da bobina sem proteção. | Aplicar degraus e perfis rápidos de referência. Medir pico, erro de seguimento e tempo de recuperação. Sob o modelo RL nominal, 12 V sustentados tenderiam a 2,4 A. |
| 3 | Depois de resolver o contato e caracterizar o atuador, testar a sensibilidade a `τ_val`, ao período de controle e à pista. Se o compromisso persistir, comparar skyhook e skyhook–groundhook híbrido na mesma campanha. | Separar o ajuste da validação com sementes adicionais. Reportar RMS de aceleração, carga dinâmica, força mínima, tempo sem contato e curso. Alterar um fator por vez antes de testar as combinações. [Díaz-Choque et al. (2021)](https://onlinelibrary.wiley.com/doi/abs/10.1155/2021/8084343) |

## Resultados para a revisão

A reprodução independente em Python/C, com integração RK4, comparou dez ganhos semiativos e dez amortecimentos passivos em cinco trechos ISO. Todo candidato apresentou força normal não positiva em pelo menos um trecho. O ganho de 8000 N·s/m foi usado nas figuras de diagnóstico por ter o maior valor de força normal mínima no pior trecho entre os ganhos semiativos testados. Essa força mínima ainda ficou em −793,5 N. O estudo deixou a escolha do ganho final em aberto. O roteiro MATLAB reaproveita o modelo Simulink do projeto para conferir a campanha quando houver execução nesse ambiente. [Critério e resultado da varredura](../../versoes/v3/resultados/selecao.csv) · [Tabela comparativa](../../versoes/v3/resultados/tabela_comparativa.csv) · [Rotina Simulink](../../modelo/executar_v3_simulink.m)

| Ensaio com o ganho exploratório | Aceleração RMS vs. passiva de 1500 N·s/m | Carga dinâmica RMS vs. passiva | Condição de contato no modelo |
|---|---:|---:|---|
| Lombada | −16,49% | −14,64% | Força normal positiva nos dois ramos. |
| ISO 8608 · média de cinco trechos | −13,82% | +13,13% | Força normal não positiva em 5/5 trechos semiativos e 2/5 passivos. |

A análise de sensibilidade já explorou períodos de 0,5 a 2 ms e constantes de tempo da válvula de 7,5 a 30 ms, um fator por vez. Na faixa ensaiada, nenhum ajuste testado resolveu a perda de contato prevista nos cinco trechos semiativos. A proposta é repetir essa análise com um pneu de contato unilateral e usar trechos adicionais para a validação do ajuste. [Resultados de sensibilidade](../../versoes/v3/resultados/sensibilidade_resumo.csv)

## Complemento opcional de conforto

A atividade opcional ainda está pendente. O cronograma condiciona sua execução à conclusão das semanas 1 a 4. Quando essa condição for atendida, aplicar a ponderação vertical Wk ao histórico completo de aceleração da carroceria e calcular o RMS ponderado na mesma janela de cada comparação. Documentar edição e emenda consultadas, amostragem, método de discretização e tratamento do transiente inicial. Conferir a resposta em frequência do filtro contra a especificação normativa antes de usar o resultado. Informar no relatório que a saída é um indicador ponderado da **carroceria**. Uma avaliação da exposição do ocupante exige caracterizar a vibração na interface com o assento. Esta atividade está descrita para execução futura. [ISO 2631-1:1997](https://www.iso.org/standard/7612.html) · [Emenda 1:2010](https://www.iso.org/standard/45604.html) · [Exemplo de medição no assento com Wk](https://pmc.ncbi.nlm.nih.gov/articles/PMC5728521/)
