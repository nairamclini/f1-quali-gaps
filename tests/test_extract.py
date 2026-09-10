"""Testes da ingestao.

Nao tocam a rede. Testam as funcoes puras -- que sao justamente as que
carregam as decisoes (idempotencia do caminho, conversao de timedelta).
Teste que depende de download e lento e falha por motivo errado.
"""

import pandas as pd

from ingest.extract import (
    drivers_without_valid_lap,
    fastest_lap_per_driver,
    raw_path,
    timedeltas_to_seconds,
)


def test_raw_path_e_deterministico():
    primeiro = raw_path("laps", 2025, 1, "Q")
    segundo = raw_path("laps", 2025, 1, "Q")
    assert primeiro == segundo


def test_raw_path_usa_padding_de_dois_digitos():
    # round=01 e nao round=1: garante ordenacao lexicografica correta no disco.
    caminho = raw_path("laps", 2025, 1, "Q")
    assert "round=01" in str(caminho)


def test_raw_path_separa_por_tipo_e_sessao():
    laps = raw_path("laps", 2025, 1, "Q")
    telemetry = raw_path("telemetry", 2025, 1, "Q")
    assert laps != telemetry


def test_timedelta_vira_coluna_de_segundos():
    df = pd.DataFrame({"LapTime": pd.to_timedelta(["0 days 00:01:30.5"])})
    resultado = timedeltas_to_seconds(df)
    assert "LapTime" not in resultado.columns
    assert resultado["LapTime_seconds"].iloc[0] == 90.5


def test_timedelta_nao_mexe_em_coluna_normal():
    df = pd.DataFrame({"Driver": ["VER"], "Speed": [318]})
    resultado = timedeltas_to_seconds(df)
    assert list(resultado.columns) == ["Driver", "Speed"]


def test_fastest_lap_pega_uma_volta_por_piloto():
    laps = pd.DataFrame(
        {
            "Driver": ["VER", "VER", "NOR"],
            "LapNumber": [1, 2, 1],
            "LapTime": pd.to_timedelta(["0:01:30", "0:01:28", "0:01:29"]),
        }
    )
    resultado = fastest_lap_per_driver(laps)
    assert len(resultado) == 2
    assert resultado[resultado["Driver"] == "VER"]["LapNumber"].iloc[0] == 2


def test_fastest_lap_ignora_volta_sem_tempo():
    # Volta de box / abortada vem com LapTime nulo. Nao pode virar "a mais rapida".
    laps = pd.DataFrame(
        {
            "Driver": ["VER", "VER"],
            "LapNumber": [1, 2],
            "LapTime": pd.to_timedelta(["0:01:30", pd.NaT]),
        }
    )
    resultado = fastest_lap_per_driver(laps)
    assert len(resultado) == 1
    assert resultado["LapNumber"].iloc[0] == 1


def test_identifica_piloto_que_ficou_de_fora():
    # Caso real: BEA em Melbourne 2025, uma volta so, sem tempo registrado.
    laps = pd.DataFrame(
        {
            "Driver": ["VER", "BEA"],
            "LapNumber": [1, 1],
            "LapTime": pd.to_timedelta(["0:01:30", pd.NaT]),
        }
    )
    fastest = fastest_lap_per_driver(laps)
    assert drivers_without_valid_lap(laps, fastest) == ["BEA"]


def test_ninguem_de_fora_quando_todos_tem_volta():
    laps = pd.DataFrame(
        {
            "Driver": ["VER", "NOR"],
            "LapNumber": [1, 1],
            "LapTime": pd.to_timedelta(["0:01:30", "0:01:31"]),
        }
    )
    fastest = fastest_lap_per_driver(laps)
    assert drivers_without_valid_lap(laps, fastest) == []
