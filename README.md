# f1-quali-gaps

Pipeline de analise de gaps de qualifying da Formula 1.

**Pergunta de negocio:** onde, especificamente, um piloto ganha ou perde tempo
em relacao ao pole sitter numa volta de qualifying?

Tempo de setor nao responde isso — setor e grosso demais para apontar curva.
Este projeto reconstroi o delta ponto a ponto da volta, a partir de telemetria.

## O que ele mostra

Qualifying da Australia 2025. Piastri terminou 0,084 s atras de Norris. O
pipeline mostra que esse numero esconde uma volta em que ele passou quase todo
o ultimo setor **na frente**:

| Trecho | Ganho/perda | Acumulado | Vel. minima |
|---|---|---|---|
| 4000–4100 m | **−0,128 s** (ganhou) | −0,153 s | 131 km/h |
| 4100–4200 m | **+0,130 s** (perdeu) | −0,024 s | 122 km/h |
| 4500–4600 m | −0,052 s (ganhou) | −0,049 s | 110 km/h |
| 4600–4700 m | **+0,116 s** (perdeu) | **+0,067 s** | 96 km/h |

Duas coisas aparecem aqui, e nenhuma e visivel num tempo de setor. Primeiro,
entre 4000 e 4200 m ele ganha 0,128 s e devolve 0,130 s no trecho seguinte:
entra mais rapido e paga na saida. Segundo, e decisivo: ele chega em 4600 m
ainda 0,049 s na frente e perde 0,116 s numa unica curva de 96 km/h. E ali que
a volta vira — nao no tempo total.

![Onde PIA perde tempo para NOR](analysis/output/gap_PIA.png)

O painel de cima e o placar acumulado; o de baixo e onde agir. Vermelho e tempo
perdido no trecho, azul e tempo ganho. O `.csv` gerado ao lado do grafico tem os
mesmos numeros em tabela, para quem nao le pela cor.

## Como rodar

```powershell
# Setup (Windows / PowerShell)
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -e ".[dev]"

# Ingestao: FastF1 -> Parquet
python -m ingest.extract --season 2025 --round 1

# Transformacao e testes
cd f1_dbt
dbt build

# Grafico + tabela equivalente
python -m analysis.visualizations --driver PIA
```

Qualidade:

```powershell
ruff check .
pytest tests/ -v
```

## Arquitetura

```
FastF1  ->  Parquet (raw)  ->  DuckDB  ->  dbt  ->  grafico
         ingest/                        staging      analysis/
                                        intermediate
                                        marts
```

- **Python move, SQL transforma.** `ingest/` nao sabe o que e um gap; toda regra
  de negocio vive no dbt.
- **Raw imutavel.** Parquet cru e reprocessavel: bug de decodificacao se
  conserta sem baixar tudo de novo.
- **Idempotente.** Rodar a ingestao duas vezes produz arquivos com hash
  identico. Verificado, nao presumido.

Modelos:

| Camada | Modelo | Papel |
|---|---|---|
| staging | `stg_fastf1__laps`, `stg_fastf1__telemetry` | 1:1 com o raw, tipagem e renomeacao |
| intermediate | `int_interpolate__telemetry_grid` | reamostra todas as voltas numa base comum |
| intermediate | `int_compute__delta_to_pole` | calcula o delta contra o pole |
| marts | `fct_qualifying_gaps`, `dim_driver` | consumo, por trecho de 100 m |

## O problema central, e como ele foi resolvido errado primeiro

Comparar duas voltas exige compara-las no mesmo ponto da pista. O dado nao
entrega isso: cada piloto tem ~576 amostras em instantes diferentes, e a
distancia da FastF1 e derivada integrando velocidade, entao acumula erro
proprio de cada carro — a mesma volta mede de 5.219,6 m a 5.252,0 m.

A primeira versao (ADR-0003) usou uma grade de metros absolutos. O teste de
reconciliacao reprovou: o delta reconstruido subestimava o gap de 17 dos 18
pilotos, e o erro tinha correlacao de **−1,0** com a distancia maxima de cada
piloto. Correlacao perfeita — nao era ruido, era o metodo.

A correcao (ADR-0004) foi comparar em **posicao relativa** (0 = inicio da volta,
1 = chegada) em vez de metros. Isso e valido porque foi medido que a telemetria
de cada piloto cobre exatamente uma volta cronometrada (sobra de 0,000 s para
os 19). Depois da mudanca, o delta reconstruido bate com o cronometro oficial
**exatamente**, para todos os pilotos.

O teste que reprovou o metodo continua no `dbt build`, agora com tolerancia de
0,01 s. Ele ja provou que funciona.

## Testes

`dbt build` roda 34 testes. Dois deles nao verificam se o dado chegou, e sim se
a analise faz sentido:

- **`assert_sector_times_reconcile_with_lap_time`** — a soma dos tres setores
  bate com o tempo de volta. Valida a premissa sobre o dado de origem.
- **`assert_final_delta_matches_lap_time_gap`** — o delta acumulado na chegada
  bate com a diferenca real de tempo de volta. Valida a matematica contra um
  numero que nao passou por interpolacao nenhuma: o cronometro.

Mais 9 testes Python (`pytest`) nas funcoes puras da ingestao.

## Decisoes registradas

| ADR | Assunto |
|---|---|
| [0001](docs/adrs/0001-stack.md) | Stack: FastF1, DuckDB, dbt |
| [0002](docs/adrs/0002-granularidade-do-raw.md) | Granularidade da camada raw |
| [0003](docs/adrs/0003-grade-de-distancia.md) | Grade de distancia — **substituido** |
| [0004](docs/adrs/0004-base-de-comparacao-relativa.md) | Posicao relativa como base de comparacao |

## Limitacoes conhecidas

- Telemetria so da volta valida mais rapida de cada piloto (ADR-0002). Piloto
  sem volta valida nao aparece na analise — o log da ingestao avisa quando isso
  acontece.
- A extracao pega a volta mais rapida sem verificar se ela foi deletada por
  limite de pista. Verificado em 2025 R01: nenhuma foi.
- Uma sessao por vez. Comparacao entre corridas nao esta no escopo.
