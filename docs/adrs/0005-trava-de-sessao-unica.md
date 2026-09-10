# ADR-0005 — Trava explicita de sessao unica

**Data:** 11/09/2026
**Status:** aceito

## Contexto

`driver_bounds`, `pole_driver` e o ASOF JOIN em `int_interpolate__telemetry_grid`
e `int_compute__delta_to_pole` agrupam e comparam apenas por `driver_code`, sem
particionar por `season`/`round_number`/`session_name`. O projeto sempre
operou com uma sessao por vez, mas nada no codigo impedia carregar uma segunda.

Testado na pratica: extraiu-se 2025 R02 junto com o R01 ja carregado e rodou-se
`dbt build`. O pole global (NOR, que correu nas duas sessoes) fez
`pole_reference` ganhar duas linhas por `grid_index` — uma por sessao — e o
join em `int_compute__delta_to_pole` multiplicou cada linha por 2. Isso
estourou o teste `unique` de `grid_point_id` (19.500 duplicatas) e a
reconciliacao (18 falhas). Falha alta e obvia.

Mas essa falha alta foi contingente, nao garantida: aconteceu porque o pole
global correu nas duas sessoes. Se o pole global tivesse corrido em uma so
sessao — reserva, substituicao, round pulado — nao haveria fan-out: cada
`grid_index` casaria com uma unica linha de pole, e pilotos da OUTRA sessao
seriam comparados contra o eixo de tempo de uma sessao diferente. Delta
errado, sem erro nenhum. E a mesma classe de falha que os ADR-0003/0004 ja
mostraram: numero errado sem aviso e pior que build quebrado. Aqui o build
quebrado foi sorte de calendario, nao garantia do codigo.

## Decisao

Teste singular `assert_single_session_loaded`: conta sessoes distintas
(`season`, `round_number`, `session_name`) em `stg_fastf1__laps` e reprova o
build se houver mais de uma. Roda antes de qualquer model de intermediate ou
marts consumir o dado.

## Alternativas consideradas

- **Confiar nos testes `unique` existentes para pegar o problema.** Rejeitada:
  o experimento mostrou que isso so funciona quando o pole global corre em
  multiplas sessoes. E uma rede com buraco conhecido, nao uma trava.
- **Particionar os models por sessao agora.** E o conserto de verdade, mas e
  trabalho de escopo maior (grid, pole e ASOF JOIN todos teriam que carregar
  a chave de sessao). Fica registrado como proximo passo quando o projeto
  precisar de multi-sessao de fato — nao antes, por scope lock.
- **Nao fazer nada, documentar a limitacao em prosa.** Ja estava documentado
  no README como "fora de escopo". Nao impede alguem de rodar `extract.py`
  duas vezes por engano e so descobrir o problema investigando por que os
  numeros nao batem.

## Consequencias

- Rodar a ingestao para uma segunda sessao sem apagar a primeira agora quebra
  o `dbt build` imediatamente, com mensagem clara, em vez de produzir gap
  errado ou depender de sorte de calendario para estourar um teste `unique`.
- Quando o suporte a multi-sessao for implementado de verdade, este teste sai
  ou vira uma verificacao de consistencia por sessao.
