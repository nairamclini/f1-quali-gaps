"""Caminhos e defaults da ingestao.

Unico lugar do projeto que sabe onde as coisas moram no disco. O cache do FastF1
e o diretorio de dados sao definidos aqui e em nenhum outro lugar.
"""

from pathlib import Path

# parent.parent porque este arquivo esta em ingest/, uma pasta abaixo da raiz.
PROJECT_ROOT = Path(__file__).resolve().parent.parent

DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
DUCKDB_PATH = DATA_DIR / "f1_quali_gaps.duckdb"

# Cache do FastF1: evita rebaixar a mesma sessao a cada execucao.
# Esta no .gitignore. Pode ser apagado a qualquer momento sem perda.
CACHE_DIR = PROJECT_ROOT / "cache"

DEFAULT_SESSION = "Q"
