# Fonte das curvas do ZF SACHS CDC

**Ding, Z.; Zhao, F.; Qin, Y.; Tan, C.** *Adaptive neural network control for semi-active vehicle suspensions*. Journal of Vibroengineering, v. 19, n. 4, 2017. [Artigo no site da revista](https://www.extrica.com/article/18045) · [PDF](https://www.extrica.com/article/18045/pdf)

A seção 3 descreve o ensaio de um amortecedor ZF SACHS CDC em bancada MTS. A corrente variou de 0 a 1,8 A em incrementos de 0,2 A, e as velocidades de pico testadas chegaram a 1,5 m/s. A Figura 3 mostra o mapa de força e velocidade. A Figura 4 e a Tabela 1 trazem as retas ajustadas aos limites mais macio e mais firme. São essas retas que usamos no benchmark. [Seção 3, Figuras 3 e 4 e Tabela 1](https://www.extrica.com/article/18045)

No código, `LimitesCdc` calcula a faixa de força para os dois sentidos de movimento. A posição do atuador na simulação determina onde a força fica entre os dois limites por interpolação linear. Mantivemos a eletrônica da V3 e adotamos 15 ms para o caso principal. As forças, a vibração da carroceria e o contato com a pista ao longo do tempo são saídas da nossa simulação. [Implementação](../Simulacao.cs)
