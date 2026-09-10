"""Grafico de gap de qualifying: onde um piloto perde tempo para o pole sitter.

Le do mart `fct_qualifying_gaps` no DuckDB. Nao recalcula nada -- se a analise
mudar, ela muda no dbt, nao aqui. Este script so desenha.

Uso:
    python -m analysis.visualizations --driver PIA
"""

from __future__ import annotations

import argparse
from pathlib import Path

import duckdb
import matplotlib

# Backend sem janela: o script tem que rodar igual no laptop e no CI.
matplotlib.use("Agg")

import matplotlib.pyplot as plt  # noqa: E402  (precisa vir depois do use())

from ingest.config import DUCKDB_PATH, PROJECT_ROOT  # noqa: E402

OUTPUT_DIR = PROJECT_ROOT / "analysis" / "output"

# Paleta e chrome: valores documentados e validados, nao escolhidos no olho.
SURFACE = "#fcfcfb"
INK_PRIMARY = "#0b0b0b"
INK_SECONDARY = "#52514e"
INK_MUTED = "#898781"
GRIDLINE = "#e1e0d9"
BASELINE = "#c3c2b7"

# Par divergente azul <-> vermelho: polos que leem como opostos.
COLOR_LOSS = "#e34948"  # perdeu tempo
COLOR_GAIN = "#2a78d6"  # ganhou tempo

SEGMENT_WIDTH_M = 100


def fetch_driver_gaps(driver: str) -> tuple[list[dict], dict]:
    """Le os trechos do piloto e os metadados da sessao."""
    con = duckdb.connect(str(DUCKDB_PATH), read_only=True)
    try:
        rows = con.execute(
            """
            select
                segment_start_m,
                delta_change_seconds,
                cumulative_delta_seconds,
                min_speed_kph
            from fct_qualifying_gaps
            where driver_code = ?
            order by segment_start_m
            """,
            [driver],
        ).fetchall()

        if not rows:
            raise SystemExit(f"Piloto '{driver}' nao encontrado no mart.")

        meta_row = con.execute(
            """
            select
                any_value(team),
                any_value(total_gap_seconds),
                any_value(season),
                any_value(round_number),
                (select any_value(driver_code)
                 from fct_qualifying_gaps
                 where is_pole_sitter)
            from fct_qualifying_gaps
            where driver_code = ?
            """,
            [driver],
        ).fetchone()
    finally:
        con.close()

    segments = [
        {
            "start_m": r[0],
            "delta_change": r[1],
            "cumulative": r[2],
            "min_speed": r[3],
        }
        for r in rows
    ]
    meta = {
        "team": meta_row[0],
        "total_gap": meta_row[1],
        "season": meta_row[2],
        "round_number": meta_row[3],
        "pole_driver": meta_row[4],
    }
    return segments, meta


def _style_axis(ax) -> None:
    """Grade e eixos recessivos: hairline solida, nunca tracejada."""
    ax.set_facecolor(SURFACE)
    ax.grid(axis="y", color=GRIDLINE, linewidth=0.6, linestyle="-")
    ax.set_axisbelow(True)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color(BASELINE)
        ax.spines[side].set_linewidth(0.8)
    ax.tick_params(colors=INK_MUTED, labelsize=9, length=0)


def plot_driver_gap(driver: str, segments: list[dict], meta: dict) -> Path:
    plt.rcParams["font.family"] = ["Segoe UI", "DejaVu Sans", "sans-serif"]

    figure, (ax_cumulative, ax_change) = plt.subplots(
        2,
        1,
        figsize=(11, 7),
        sharex=True,
        gridspec_kw={"height_ratios": [1, 1.2], "hspace": 0.18},
    )
    figure.patch.set_facecolor(SURFACE)

    starts = [s["start_m"] for s in segments]
    cumulative = [s["cumulative"] for s in segments]
    changes = [s["delta_change"] for s in segments]

    # --- Painel 1: delta acumulado. Serie unica, entao sem legenda.
    ax_cumulative.plot(starts, cumulative, color=COLOR_GAIN, linewidth=2)
    ax_cumulative.axhline(0, color=BASELINE, linewidth=0.8)
    ax_cumulative.set_ylabel("Delta acumulado (s)", color=INK_SECONDARY, fontsize=10)
    _style_axis(ax_cumulative)
    ax_cumulative.set_title(
        f"Onde {driver} ({meta['team']}) perde tempo para {meta['pole_driver']}\n"
        f"Qualifying {meta['season']} R{meta['round_number']:02d} "
        f"— gap total de {meta['total_gap']:.3f} s",
        color=INK_PRIMARY,
        fontsize=13,
        loc="left",
        pad=14,
    )

    # --- Painel 2: ganho/perda por trecho. Barra divergente.
    # Eixo x compartilhado, nunca segundo eixo y: escalas diferentes no mesmo
    # plot inventariam correlacao que o dado nao tem.
    colors = [COLOR_LOSS if c > 0 else COLOR_GAIN for c in changes]
    ax_change.bar(
        starts,
        changes,
        width=SEGMENT_WIDTH_M - 10,  # folga entre barras, sem borda desenhada
        color=colors,
        align="edge",
    )
    ax_change.axhline(0, color=BASELINE, linewidth=0.8)
    # Folga vertical para os rotulos diretos caberem dentro da area de plotagem.
    # Sem isto o rotulo do trecho de maior ganho cai em cima dos numeros do eixo x.
    span = max(abs(min(changes)), abs(max(changes)))
    ax_change.set_ylim(-span * 1.6, span * 1.6)
    ax_change.set_ylabel("Ganho / perda no trecho (s)", color=INK_SECONDARY, fontsize=10)
    ax_change.set_xlabel("Distancia na volta (m)", color=INK_SECONDARY, fontsize=10)
    _style_axis(ax_change)

    # Rotulo direto so nos extremos -- numero em toda barra vira ruido.
    worst = sorted(segments, key=lambda s: s["delta_change"], reverse=True)[:2]
    best = min(segments, key=lambda s: s["delta_change"])
    for segment in (*worst, best):
        ax_change.annotate(
            f"{segment['delta_change']:+.3f}s\n{segment['min_speed']:.0f} km/h",
            xy=(segment["start_m"] + SEGMENT_WIDTH_M / 2, segment["delta_change"]),
            xytext=(0, 8 if segment["delta_change"] > 0 else -26),
            textcoords="offset points",
            ha="center",
            fontsize=8.5,
            color=INK_SECONDARY,  # texto usa tinta, nunca a cor da serie
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / f"gap_{driver}.png"
    figure.savefig(output_path, dpi=150, facecolor=SURFACE, bbox_inches="tight")
    plt.close(figure)
    return output_path


def write_table_twin(driver: str, segments: list[dict]) -> Path:
    """Equivalente em tabela do grafico.

    Grafico nao pode ser o unico caminho para o numero: quem nao distingue as
    cores, ou quem quer conferir, le o CSV.
    """
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / f"gap_{driver}.csv"
    lines = ["trecho_inicio_m,trecho_fim_m,ganho_perda_s,acumulado_s,vel_minima_kph"]
    for s in segments:
        lines.append(
            f"{s['start_m']},{s['start_m'] + SEGMENT_WIDTH_M},"
            f"{s['delta_change']:.4f},{s['cumulative']:.4f},{s['min_speed']:.1f}"
        )
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Grafico de gap de qualifying.")
    parser.add_argument("--driver", required=True, help="Codigo do piloto, ex.: PIA")
    args = parser.parse_args()

    driver = args.driver.upper()
    segments, meta = fetch_driver_gaps(driver)
    chart = plot_driver_gap(driver, segments, meta)
    table = write_table_twin(driver, segments)
    print(f"grafico: {chart}")
    print(f"tabela:  {table}")


if __name__ == "__main__":
    main()
