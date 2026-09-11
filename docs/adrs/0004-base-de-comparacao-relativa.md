# ADR-0004 — Posicao relativa como base de comparacao

**Data:** 10/09/2026
**Status:** aceito
**Substitui:** ADR-0003

## Contexto

O ADR-0003 decidiu comparar as voltas numa grade de metros absolutos. O teste
de reconciliacao `assert_final_delta_matches_lap_time_gap` reprovou o metodo.

O delta interpolado subestimou o gap de **17 dos 18** pilotos nao-pole, de
0,047 s a 0,339 s. Viés sistematico, nao ruido.

Duas hipoteses foram medidas:

- **Recorte da telemetria desalinhado da volta cronometrada.** Refutada: a
  duracao da telemetria bate com o tempo de volta em **0,000 s para os 19
  pilotos**.
- **Eixo de distancia esticado, diferente por piloto.** Confirmada. A
  correlacao entre a distancia maxima do piloto e o erro de reconciliacao e de
  **-1,0**. A correlacao com o tempo de volta e de apenas -0,311 — ou seja, o
  erro nao tem relacao com ser lento, e sim com o comprimento do eixo.

Mecanismo: a distancia da FastF1 e derivada integrando velocidade e acumula
erro proprio de cada carro (5.219,6 m a 5.252,0 m para a mesma volta). Cortar
todos no menor valor corta cada piloto num ponto fisico diferente — quem tem
eixo mais longo perde um pedaco maior do fim da volta, e e justamente ali que
ele seguiria perdendo tempo. O corte subestima o gap na proporcao exata do que
foi cortado, que e o que a correlacao de -1,0 descreve.

## Decisao

Comparar em **posicao relativa**: a distancia de cada amostra dividida pela
distancia maxima daquele piloto, resultando em 0 no inicio da volta e 1 na
linha de chegada. Grade de **501 pontos** (indice inteiro de 0 a 500, dividido
por 500), com interpolacao linear entre as amostras que cercam cada ponto.

Metros continuam existindo como `nominal_distance_m`, derivado da posicao
relativa apenas para leitura humana e para agrupar em trechos de 100 m no
mart. Nao sao mais a base de comparacao.

## Por que isto e valido

Porque foi medido que a telemetria de cada piloto cobre exatamente uma volta
cronometrada (sobra de 0,000 s). Se cada serie cobre uma volta inteira e so
uma, entao "50% da volta" e o mesmo ponto fisico para todos, mesmo que os
eixos de metros discordem entre si.

Efeito colateral desejavel: o ultimo ponto da grade cai **exatamente** sobre a
ultima amostra de cada piloto, sem interpolacao. O delta ali passa a ser, por
construcao, `tempo_do_piloto - tempo_do_pole`. Por isso a tolerancia do teste
de reconciliacao caiu de 0,25 s para **0,01 s**.

## Alternativas consideradas

- **Manter metros e alargar a tolerancia do teste.** Rejeitada sem discussao:
  seria trocar a corretude por um build verde. O teste estava certo.
- **Manter metros e reescalar o eixo de cada piloto por um fator.** E o que a
  posicao relativa faz, so que com passo intermediario desnecessario.
- **Usar `RelativeDistance`, coluna que a propria FastF1 fornece.** Chegaria ao
  mesmo lugar, mas nao foi extraida na camada raw (ADR-0002) e exigiria nova
  ingestao. Calcular a partir de `Distance` da o mesmo resultado com o dado que
  ja esta em disco.

## Consequencias

- O eixo x da analise passa a ser fracao de volta. Para casar com referencia de
  pista (nome de curva), converte-se por `nominal_distance_m`, com a ressalva
  de que a escala nominal e uma media entre pilotos.
- A comparacao entre sessoes ou circuitos diferentes fica mais natural: 0 a 1
  e sempre 0 a 1.
- O teste de reconciliacao vira a defesa permanente contra regressao deste
  tipo. Ele ja provou que funciona: reprovou a primeira versao do metodo.

## Validacao adicional (11/09/2026)

Testado tambem contra Monaco 2025 (R08), extraido, validado e removido do raw
em seguida — o projeto continua com uma sessao carregada (ADR-0005). Escolhido
de proposito por ser o oposto do traçado fluido de Melbourne: curvas fechadas,
volta de ~3.290 m contra ~5.236 m, com a curva mais lenta do calendario (~60-80
km/h).

A divergencia do eixo de distancia entre pilotos, a mesma que motivou este ADR,
e proporcionalmente **maior** em Monaco: 27,0 m de amplitude num circuito mais
curto da ~0,82% de divergencia relativa, contra ~0,62% em Melbourne (32,4 m em
~5.236 m). Faz sentido — mais mudancas de direcao por metro de pista acumulam
mais erro de integracao. Mesmo assim, a reconciliacao final se manteve **exata**
(erro maximo de 0,0 s entre os 20 pilotos), e o `dbt build` fechou 41/41 sem
alteracao de codigo.

Conclusao: o metodo de posicao relativa nao so corrigiu o vies medido em
Melbourne, como se mostra robusto num circuito onde a causa raiz do vies
(erro de integracao de distancia) e proporcionalmente mais forte. Isso e
evidencia a favor da decisao, nao so repeticao do mesmo teste.
