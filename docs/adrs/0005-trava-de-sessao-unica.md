# ADR-0005 — Trava explícita de sessão única

**Data:** 11/09/2026
**Status:** aceito

## Contexto

`driver_bounds`, `pole_driver` e o ASOF JOIN em `int_interpolate__telemetry_grid`
e `int_compute__delta_to_pole` agrupam e comparam apenas por `driver_code`, sem
particionar por `season`/`round_number`/`session_name`. O projeto sempre
operou com uma sessão por vez, mas nada no código impedia carregar uma segunda.

Testado na prática: extraiu-se 2025 R02 junto com o R01 já carregado e rodou-se
`dbt build`. O pole global (NOR, que correu nas duas sessões) fez
`pole_reference` ganhar duas linhas por `grid_index` — uma por sessão — e o
join em `int_compute__delta_to_pole` multiplicou cada linha por 2. Isso
estourou o teste `unique` de `grid_point_id` (19.500 duplicatas) e a
reconciliação (18 falhas). Falha alta e óbvia.

Mas essa falha alta foi contingente, não garantida: aconteceu porque o pole
global correu nas duas sessões. Se o pole global tivesse corrido em uma só
sessão — reserva, substituição, round pulado — não haveria fan-out: cada
`grid_index` casaria com uma única linha de pole, e pilotos da OUTRA sessão
seriam comparados contra o eixo de tempo de uma sessão diferente. Delta
errado, sem erro nenhum. É a mesma classe de falha que os ADR-0003/0004 já
mostraram: número errado sem aviso é pior que build quebrado. Aqui o build
quebrado foi sorte de calendário, não garantia do código.

## Decisão

Teste singular `assert_single_session_loaded`: conta sessões distintas
(`season`, `round_number`, `session_name`) em `stg_fastf1__laps` e reprova o
build se houver mais de uma. Roda antes de qualquer model de intermediate ou
marts consumir o dado.

## Alternativas consideradas

- **Confiar nos testes `unique` existentes para pegar o problema.** Rejeitada:
  o experimento mostrou que isso só funciona quando o pole global corre em
  múltiplas sessões. É uma rede com buraco conhecido, não uma trava.
- **Particionar os models por sessão agora.** É o conserto de verdade, mas é
  trabalho de escopo maior (grid, pole e ASOF JOIN todos teriam que carregar
  a chave de sessão). Fica registrado como próximo passo quando o projeto
  precisar de multi-sessão de fato — não antes, por scope lock.
- **Não fazer nada, documentar a limitação em prosa.** Já estava documentado
  no README como "fora de escopo". Não impede alguém de rodar `extract.py`
  duas vezes por engano e só descobrir o problema investigando por que os
  números não batem.

## Consequências

- Rodar a ingestão para uma segunda sessão sem apagar a primeira agora quebra
  o `dbt build` imediatamente, com mensagem clara, em vez de produzir gap
  errado ou depender de sorte de calendário para estourar um teste `unique`.
- Quando o suporte a multi-sessão for implementado de verdade, este teste sai
  ou vira uma verificação de consistência por sessão.
