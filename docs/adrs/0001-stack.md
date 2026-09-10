# ADR-0001 — Stack do f1-quali-gaps

**Data:** 10/09/2026
**Status:** aceito

## Contexto

Projeto de prova de 21 dias, executado num laptop, por uma pessoa. Precisa
demonstrar competencia de analytics engineering de ponta a ponta e ficar
publicavel no fim do prazo.

## Decisao

FastF1 (ingestao) -> Parquet (raw) -> DuckDB (warehouse) -> dbt-core (transformacao)
-> SQL/Python (visualizacao). Git com ADRs, GitHub Actions rodando `dbt build` no PR.

## Alternativas consideradas

- **Postgres em Docker no lugar do DuckDB.** Mais parecido com producao, mas exige
  container rodando, credencial e um servico para o CI subir. DuckDB e um arquivo:
  o CI so precisa de `pip install`. Para dado de uma temporada, arquivo basta.
- **Pandas puro, sem dbt.** Menos peca movel, mas joga fora exatamente o que o
  projeto quer demonstrar: modelagem em camadas, teste declarativo e linhagem.
- **BigQuery.** Conhecido pelo dev, porem exige conta, credencial e custo. Some
  a vantagem de "clona e roda" para quem for avaliar o repositorio.

## Consequencias

- O CI e trivial e roda em segundos. O repositorio clona e roda sem infra.
- O `.duckdb` nunca e versionado: e derivado, reconstruido por `dbt build`.
- Se um dia o volume crescer, o DuckDB e o limite. Nao e problema em 21 dias.
