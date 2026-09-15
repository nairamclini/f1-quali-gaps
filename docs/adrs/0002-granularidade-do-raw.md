# ADR-0002 — Granularidade da camada raw

**Data:** 10/09/2026
**Status:** aceito

## Contexto

A pergunta de negócio é "onde, especificamente, um piloto ganha ou perde tempo
em relação ao pole sitter". Responder "qual curva" exige telemetria por
distância, não apenas tempo de setor. Mas telemetria é cara: cada volta tem
milhares de amostras, e uma sessão de qualifying tem centenas de voltas.

## Decisão

Duas tabelas raw por sessão:

- **`laps`** — todas as voltas de todos os pilotos.
- **`telemetry`** — apenas a volta válida mais rápida de cada piloto.

Colunas `timedelta64` são gravadas como float de segundos, com sufixo
`_seconds`, já no raw.

## Alternativas consideradas

- **Telemetria de todas as voltas.** ~20x mais dado para responder a mesma
  pergunta. A volta de saída do box nunca será comparada com a pole.
- **Somente `laps`, sem telemetria.** Cabe num arquivo minúsculo, mas só
  consegue responder até o nível de setor. Setor é grosso demais para
  identificar curva — não responde a pergunta.
- **Manter `timedelta` no Parquet.** Seria mais fiel ao "raw é intocado", mas
  Parquet grava timedelta como `duration` e a leitura disso no DuckDB é
  frágil e ruim de manipular em SQL. A conversão para segundos é mecânica e
  sem perda; tipagem e renomeação *semântica* continuam em staging.

## Consequências

- Ampliar a análise para voltas não-rápidas exige nova extração. Aceito: está
  fora do escopo dos 21 dias.
- O raw deixa de ser byte-a-byte idêntico ao que a FastF1 entrega. Registrado
  aqui para que a diferença seja uma escolha, e não uma surpresa.
- `laps` guarda todas as voltas, então a reconciliação (soma dos setores vs.
  tempo da volta) pode ser feita sem nova extração.
