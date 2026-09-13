"""Configuración centralizada: rutas y constantes de las fuentes de datos.

Ver docs/03-ingesta-de-datos.md. Nada de rutas ni URLs sueltas en el resto
del paquete: todo pasa por aquí.
"""

from pathlib import Path

# tools/src/fittracker_data/config.py -> tools/
TOOLS_ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = TOOLS_ROOT.parent

DATA_RAW_DIR = TOOLS_ROOT / "data" / "raw"
DATA_INTERIM_DIR = TOOLS_ROOT / "data" / "interim"
CATALOG_OUTPUT_DIR = REPO_ROOT / "app" / "assets" / "catalog"

# --- free-exercise-db (Unlicense / dominio público) ---
# Ver docs/00-decisiones.md ADR-003.
FREE_EXERCISE_DB_REPO = "yuhonas/free-exercise-db"
FREE_EXERCISE_DB_JSON_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db"
    "/main/dist/exercises.json"
)
FREE_EXERCISE_DB_IMAGE_BASE_URL = (
    "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"
)

# Versión del catálogo que se compara contra app_setting.catalog_version_*
# en el dispositivo. Se sube a mano cuando el contenido cambia de forma
# que amerite resembrar (no cada vez que se regenera el archivo).
# v2: nombres, equipo y músculos traducidos al español.
# v3: v2 nunca llegó a escribir name_es en la app (bug en
# CatalogSeeder._toCompanion, corregido) — hay que resembrar de nuevo.
EXERCISES_CATALOG_VERSION = 3
