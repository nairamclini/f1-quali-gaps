# ADR-0004 — Posição relativa como base de comparação

**Data:** 10/09/2026
**Status:** aceito
**Substitui:** ADR-0003

## Contexto

O ADR-0003 decidiu comparar as voltas numa grade de metros absolutos. O teste
de reconciliação `assert_final_delta_matches_lap_time_gap` reprovou o método.

O delta interpolado subestimou o gap de **17 dos 18** pilotos não-pole, de
0,047 s a 0,339 s. Viés sistemático, não ruído.

Duas hipóteses foram medidas:

- **Recorte da telemetria desalinhado da volta cronometrada.** Refutada: a
  duração da telemetria bate com o tempo de volta em **0,000 s para os 19
  pilotos**.
- **Eixo de distância esticado, diferente por piloto.** Confirmada. A
  correlação entre a distância máxima do piloto e o erro de reconciliação é de
  **-1,0**. A correlação com o tempo de volta é de apenas -0,311 — ou seja, o
  erro não tem relação com ser lento, e sim com o comprimento do eixo.

Mecanismo: a distância da FastF1 é derivada integrando velocidade e acumula
erro próprio de cada carro (5.219,6 m a 5.252,0 m para a mesma volta). Cortar
todos no menor valor corta cada piloto num ponto físico diferente — quem tem
eixo mais longo perde um pedaço maior do fim da volta, e é justamente ali que
ele seguiria perdendo tempo. O corte subestima o gap na proporção exata do que
foi cortado, que é o que a correlação de -1,0 descreve.

## Decisão

Comparar em **posição relativa**: a distância de cada amostra dividida pela
distância máxima daquele piloto, resultando em 0 no início da volta e 1 na
linha de chegada. Grade de **501 pontos** (índice inteiro de 0 a 500, dividido
por 500), com interpolação linear entre as amostras que cercam cada ponto.

Metros continuam existindo como `nominal_distance_m`, derivado da posição
relativa apenas para leitura humana e para agrupar em trechos de 100 m no
mart. Não são mais a base de comparação.

## Por que isto é válido

Porque foi medido que a telemetria de cada piloto cobre exatamente uma volta
cronometrada (sobra de 0,000 s). Se cada série cobre uma volta inteira e só
uma, então "50% da volta" é o mesmo ponto físico para todos, mesmo que os
eixos de metros discordem entre si.

Efeito colateral desejável: o último ponto da grade cai **exatamente** sobre a
última amostra de cada piloto, sem interpolação. O delta ali passa a ser, por
construção, `tempo_do_piloto - tempo_do_pole`. Por isso a tolerância do teste
de reconciliação caiu de 0,25 s para **0,01 s**.

## Alternativas consideradas

- **Manter metros e alargar a tolerância do teste.** Rejeitada sem discussão:
  seria trocar a corretude por um build verde. O teste estava certo.
- **Manter metros e reescalar o eixo de cada piloto por um fator.** É o que a
  posição relativa faz, só que com passo intermediário desnecessário.
- **Usar `RelativeDistance`, coluna que a própria FastF1 fornece.** Chegaria ao
  mesmo lugar, mas não foi extraída na camada raw (ADR-0002) e exigiria nova
  ingestão. Calcular a partir de `Distance` dá o mesmo resultado com o dado que
  já está em disco.

## Consequências

- O eixo x da análise passa a ser fração de volta. Para casar com referência de
  pista (nome de curva), converte-se por `nominal_distance_m`, com a ressalva
  de que a escala nominal é uma média entre pilotos.
- A comparação entre sessões ou circuitos diferentes fica mais natural: 0 a 1
  é sempre 0 a 1.
- O teste de reconciliação vira a defesa permanente contra regressão deste
  tipo. Ele já provou que funciona: reprovou a primeira versão do método.

## Validação adicional (11/09/2026)

Testado também contra Mônaco 2025 (R08), extraído, validado e removido do raw
em seguida — o projeto continua com uma sessão carregada (ADR-0005). Escolhido
de propósito por ser o oposto do traçado fluido de Melbourne: curvas fechadas,
volta de ~3.290 m contra ~5.236 m, com a curva mais lenta do calendário (~60-80
km/h).

A divergência do eixo de distância entre pilotos, a mesma que motivou este ADR,
é proporcionalmente **maior** em Mônaco: 27,0 m de amplitude num circuito mais
curto dá ~0,82% de divergência relativa, contra ~0,62% em Melbourne (32,4 m em
~5.236 m). Faz sentido — mais mudanças de direção por metro de pista acumulam
mais erro de integração. Mesmo assim, a reconciliação final se manteve **exata**
(erro máximo de 0,0 s entre os 20 pilotos), e o `dbt build` fechou 41/41 sem
alteração de código.

Conclusão: o método de posição relativa não só corrigiu o viés medido em
Melbourne, como se mostra robusto num circuito onde a causa raiz do viés
(erro de integração de distância) é proporcionalmente mais forte. Isso é
evidência a favor da decisão, não só repetição do mesmo teste.
