"""Punto de entrada único de la ingesta.

uv run python -m fittracker_data.build_all
uv run python -m fittracker_data.build_all --only exercises
"""

from __future__ import annotations

import argparse
import json
import logging
from collections.abc import Sequence

from fittracker_data.config import (
    CATALOG_OUTPUT_DIR,
    EXERCISES_CATALOG_VERSION,
    FREE_EXERCISE_DB_REPO,
)
from fittracker_data.download import fetch_latest_commit_sha
from fittracker_data.exercises import (
    attach_spanish_names,
    fetch_and_normalize_exercises,
)
from fittracker_data.manifest import (
    DatasetManifestEntry,
    sha256_of_bytes,
    write_manifest,
)

logger = logging.getLogger(__name__)

_KNOWN_DATASETS = ("exercises",)


def _dump_json_deterministic(rows: list[dict[str, object]]) -> bytes:
    """Claves ordenadas, sin espacios de más, salto de línea final: el
    mismo insumo produce byte por byte la misma salida (docs/03-ingesta-de-datos.md)."""
    text = json.dumps(rows, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    return text.encode("utf-8")


def build_exercises() -> DatasetManifestEntry:
    exercises = fetch_and_normalize_exercises()

    # Import diferido: solo hace falta la API de Claude (y una key) aquí,
    # no en el resto del pipeline ni en las pruebas.
    from fittracker_data.translate import translate_exercise_names

    translations = translate_exercise_names([(e.source_id, e.name) for e in exercises])
    exercises = attach_spanish_names(exercises, translations)

    rows = [e.to_row() for e in exercises]
    payload = _dump_json_deterministic(rows)

    output_path = CATALOG_OUTPUT_DIR / "exercises.json"
    CATALOG_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(payload)
    logger.info("Escrito %s (%d filas)", output_path, len(rows))

    source_ref = fetch_latest_commit_sha(FREE_EXERCISE_DB_REPO) or "main"
    return DatasetManifestEntry(
        version=EXERCISES_CATALOG_VERSION,
        row_count=len(rows),
        sha256=sha256_of_bytes(payload),
        source=FREE_EXERCISE_DB_REPO,
        source_ref=source_ref,
        license="Unlicense",
    )


def main(argv: Sequence[str] | None = None) -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--only",
        choices=_KNOWN_DATASETS,
        help="Construir solo este dataset (por defecto: todos)",
    )
    args = parser.parse_args(argv)

    entries: dict[str, DatasetManifestEntry] = {}
    if args.only in (None, "exercises"):
        entries["exercises"] = build_exercises()

    write_manifest(CATALOG_OUTPUT_DIR, entries)
    logger.info("Manifiesto escrito con %d dataset(s)", len(entries))


if __name__ == "__main__":
    main()
