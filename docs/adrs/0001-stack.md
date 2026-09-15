# ADR-0001 — Stack do f1-quali-gaps

**Data:** 10/09/2026
**Status:** aceito

## Contexto

Projeto de prova de 21 dias, executado num laptop, por uma pessoa. Precisa
demonstrar competência de analytics engineering de ponta a ponta e ficar
publicável no fim do prazo.

## Decisão

FastF1 (ingestão) -> Parquet (raw) -> DuckDB (warehouse) -> dbt-core (transformação)
-> SQL/Python (visualização). Git com ADRs, GitHub Actions rodando `dbt build` no PR.

## Alternativas consideradas

- **Postgres em Docker no lugar do DuckDB.** Mais parecido com produção, mas exige
  container rodando, credencial e um serviço para o CI subir. DuckDB é um arquivo:
  o CI só precisa de `pip install`. Para dado de uma temporada, arquivo basta.
- **Pandas puro, sem dbt.** Menos peça móvel, mas joga fora exatamente o que o
  projeto quer demonstrar: modelagem em camadas, teste declarativo e linhagem.
- **BigQuery.** Conhecido pelo dev, porém exige conta, credencial e custo. Some
  a vantagem de "clona e roda" para quem for avaliar o repositório.

## Consequências

- O CI é trivial e roda em segundos. O repositório clona e roda sem infra.
- O `.duckdb` nunca é versionado: é derivado, reconstruído por `dbt build`.
- Se um dia o volume crescer, o DuckDB é o limite. Não é problema em 21 dias.
