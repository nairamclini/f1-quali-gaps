# ADR-0002 — Granularidade da camada raw

**Data:** 10/09/2026
**Status:** aceito

## Contexto

A pergunta de negocio e "onde, especificamente, um piloto ganha ou perde tempo
em relacao ao pole sitter". Responder "qual curva" exige telemetria por
distancia, nao apenas tempo de setor. Mas telemetria e cara: cada volta tem
milhares de amostras, e uma sessao de qualifying tem centenas de voltas.

## Decisao

Duas tabelas raw por sessao:

- **`laps`** — todas as voltas de todos os pilotos.
- **`telemetry`** — apenas a volta valida mais rapida de cada piloto.

Colunas `timedelta64` sao gravadas como float de segundos, com sufixo
`_seconds`, ja no raw.

## Alternativas consideradas

- **Telemetria de todas as voltas.** ~20x mais dado para responder a mesma
  pergunta. A volta de saida do box nunca sera comparada com a pole.
- **Somente `laps`, sem telemetria.** Cabe num arquivo minusculo, mas so
  consegue responder ate o nivel de setor. Setor e grosso demais para
  identificar curva — nao responde a pergunta.
- **Manter `timedelta` no Parquet.** Seria mais fiel ao "raw e intocado", mas
  Parquet grava timedelta como `duration` e a leitura disso no DuckDB e
  fragil e ruim de manipular em SQL. A conversao para segundos e mecanica e
  sem perda; tipagem e renomeacao *semantica* continuam em staging.

## Consequencias

- Ampliar a analise para voltas nao-rapidas exige nova extracao. Aceito: esta
  fora do escopo dos 21 dias.
- O raw deixa de ser byte-a-byte identico ao que a FastF1 entrega. Registrado
  aqui para que a diferenca seja uma escolha, e nao uma surpresa.
- `laps` guarda todas as voltas, entao a reconciliacao (soma dos setores vs.
  tempo da volta) pode ser feita sem nova extracao.
