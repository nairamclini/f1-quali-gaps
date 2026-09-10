"""FastF1 -> Parquet (camada raw).

Este modulo move dado. Nao transforma, nao calcula gap, nao sabe o que e um
pole sitter. Toda logica de negocio mora no dbt.

Uso:
    python -m ingest.extract --season 2025 --round 1
"""

from __future__ import annotations

import argparse
import logging
from pathlib import Path

import fastf1
import pandas as pd

from ingest.config import CACHE_DIR, DEFAULT_SESSION, RAW_DIR

log = logging.getLogger("ingest.extract")

# Colunas de telemetria que interessam para a pergunta de negocio.
# X/Y/Z (posicao no mapa) ficam de fora: bonitas, mas nao respondem onde se
# perde tempo. Distance e a chave da comparacao entre voltas.
TELEMETRY_COLUMNS = [
    "Distance",
    "Time",
    "Speed",
    "Throttle",
    "Brake",
    "nGear",
    "RPM",
    "DRS",
]


def timedeltas_to_seconds(df: pd.DataFrame) -> pd.DataFrame:
    """Converte toda coluna timedelta64 para float de segundos.

    `LapTime` vira `LapTime_seconds`. Motivo no ADR-0002: Parquet grava
    timedelta como tipo `duration`, e ler duration no DuckDB e desagradavel.
    Conversao mecanica e sem perda -- nao e regra de negocio.
    """
    out = df.copy()
    for column in out.columns:
        if pd.api.types.is_timedelta64_dtype(out[column]):
            out[f"{column}_seconds"] = out[column].dt.total_seconds()
            out = out.drop(columns=[column])
    return out


def raw_path(kind: str, season: int, round_number: int, session_name: str) -> Path:
    """Caminho deterministico no padrao hive (`chave=valor`).

    Mesma entrada sempre produz o mesmo caminho -- e daqui que vem a
    idempotencia. Nao ha timestamp no nome, nao ha append.
    """
    return (
        RAW_DIR
        / kind
        / f"season={season}"
        / f"round={round_number:02d}"
        / f"session={session_name}"
        / f"{kind}.parquet"
    )


def fastest_lap_per_driver(laps: pd.DataFrame) -> pd.DataFrame:
    """Uma linha por piloto: a volta valida mais rapida dele na sessao.

    Feito com pandas puro (groupby + idxmin) em vez do `pick_fastest()` da
    FastF1 -- menos dependencia de API que muda entre versoes, e fica obvio
    o que esta acontecendo.
    """
    valid = laps[laps["LapTime"].notna()]
    fastest_indexes = valid.groupby("Driver")["LapTime"].idxmin()
    return valid.loc[fastest_indexes]


def drivers_without_valid_lap(laps: pd.DataFrame, fastest: pd.DataFrame) -> list[str]:
    """Pilotos que aparecem em `laps` mas nao sobraram em `fastest`.

    Existe so para dar nome a uma ausencia. Sem isso, um piloto some entre a
    tabela de voltas e a de telemetria sem que ninguem fique sabendo.
    """
    return sorted(set(laps["Driver"]) - set(fastest["Driver"]))


def _write(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(path, index=False)
    log.info("gravado: %s (%d linhas)", path, len(df))


def extract_session(
    season: int,
    round_number: int,
    session_name: str = DEFAULT_SESSION,
) -> None:
    """Baixa uma sessao e grava duas tabelas raw: laps e telemetry."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    fastf1.Cache.enable_cache(str(CACHE_DIR))

    session = fastf1.get_session(season, round_number, session_name)
    # weather/messages nao respondem a pergunta de negocio -- nao baixa.
    session.load(laps=True, telemetry=True, weather=False, messages=False)

    laps = pd.DataFrame(session.laps)
    # sort_values antes de gravar: sem isso a ordem das linhas pode variar
    # entre execucoes e o arquivo deixa de ser byte-identico.
    laps = laps.sort_values(["Driver", "LapNumber"]).reset_index(drop=True)
    _write(timedeltas_to_seconds(laps), raw_path("laps", season, round_number, session_name))

    fastest = fastest_lap_per_driver(session.laps)

    # Piloto sem volta valida nao entra na telemetria. E esperado (ADR-0002),
    # mas acontecia em silencio -- e perda silenciosa e o que mata a confianca
    # num pipeline. O log transforma surpresa em fato conhecido.
    excluded = drivers_without_valid_lap(laps, fastest)
    if excluded:
        log.warning("sem volta valida, ausentes da telemetria: %s", ", ".join(excluded))

    frames: list[pd.DataFrame] = []
    for _, lap in fastest.iterrows():
        telemetry = lap.get_telemetry()
        # Reindex tolera coluna ausente (DRS nem sempre vem) em vez de estourar.
        frame = telemetry.reindex(columns=TELEMETRY_COLUMNS).copy()
        # Sem estas duas colunas a telemetria e um monte de numero sem dono.
        frame["Driver"] = lap["Driver"]
        frame["LapNumber"] = lap["LapNumber"]
        frames.append(frame)

    telemetry_all = pd.concat(frames, ignore_index=True)
    telemetry_all = telemetry_all.sort_values(["Driver", "Distance"]).reset_index(drop=True)
    _write(
        timedeltas_to_seconds(telemetry_all),
        raw_path("telemetry", season, round_number, session_name),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Extrai uma sessao da F1 para Parquet.")
    parser.add_argument("--season", type=int, required=True)
    parser.add_argument("--round", type=int, required=True, dest="round_number")
    parser.add_argument("--session", type=str, default=DEFAULT_SESSION)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    extract_session(args.season, args.round_number, args.session)


if __name__ == "__main__":
    main()
