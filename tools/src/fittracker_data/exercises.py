"""Ingesta del catálogo de ejercicios desde `free-exercise-db`.

Fuente: https://github.com/yuhonas/free-exercise-db — Unlicense (dominio
público), ver docs/00-decisiones.md ADR-003. Transforma al esquema de
docs/01-modelo-de-datos.md § exercise; validaciones en
docs/03-ingesta-de-datos.md § Validaciones que abortan el build.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, replace
from typing import Any

from fittracker_data.config import (
    FREE_EXERCISE_DB_IMAGE_BASE_URL,
    FREE_EXERCISE_DB_JSON_URL,
)
from fittracker_data.download import download_text
from fittracker_data.translations import translate_equipment, translate_muscles

logger = logging.getLogger(__name__)

# Si la normalización descarta más de esta fracción del dataset upstream,
# algo cambió de forma en el origen (no es una simple poda de filas malas)
# y es mejor abortar el build que publicar un catálogo truncado en silencio.
_MAX_DROP_FRACTION = 0.10


class ExerciseValidationError(Exception):
    """El dataset de ejercicios no tiene la forma esperada."""


@dataclass(frozen=True, slots=True)
class NormalizedExercise:
    """Un ejercicio ya normalizado a las columnas de `exercise`
    (docs/01-modelo-de-datos.md)."""

    source: str
    source_id: str
    name: str
    force: str | None
    level: str | None
    mechanic: str | None
    equipment: str | None
    category: str | None
    primary_muscles: list[str]
    secondary_muscles: list[str]
    instructions: list[str]
    image_urls: list[str]
    name_es: str | None = None

    def to_row(self) -> dict[str, Any]:
        """Fila lista para exportar — claves snake_case idénticas al esquema."""
        return {
            "source": self.source,
            "source_id": self.source_id,
            "name": self.name,
            "name_es": self.name_es,
            "force": self.force,
            "level": self.level,
            "mechanic": self.mechanic,
            "equipment": self.equipment,
            "category": self.category,
            "primary_muscles": self.primary_muscles,
            "secondary_muscles": self.secondary_muscles,
            "instructions": self.instructions,
            "image_urls": self.image_urls,
        }


def _normalize_one(raw: dict[str, Any]) -> NormalizedExercise:
    source_id = raw.get("id")
    name = raw.get("name")
    if not source_id or not name:
        raise ExerciseValidationError(f"ejercicio sin id o nombre: {raw!r}")

    instructions = [step for step in (raw.get("instructions") or []) if step]
    if not instructions:
        raise ExerciseValidationError(f"{source_id}: sin instrucciones")

    image_urls = [
        f"{FREE_EXERCISE_DB_IMAGE_BASE_URL}/{path}"
        for path in (raw.get("images") or [])
    ]

    return NormalizedExercise(
        source="free-exercise-db",
        source_id=str(source_id),
        name=str(name),
        force=raw.get("force"),
        level=raw.get("level"),
        mechanic=raw.get("mechanic"),
        equipment=translate_equipment(raw.get("equipment")),
        category=raw.get("category"),
        primary_muscles=translate_muscles(list(raw.get("primaryMuscles") or [])),
        secondary_muscles=translate_muscles(list(raw.get("secondaryMuscles") or [])),
        instructions=instructions,
        image_urls=image_urls,
    )


def normalize_exercises(
    raw_exercises: list[dict[str, Any]],
) -> list[NormalizedExercise]:
    """Normaliza, descarta filas inválidas con aviso, y valida el conjunto.

    Orden estable por `source_id`: la salida no debe depender del orden
    del JSON upstream (docs/03-ingesta-de-datos.md § determinismo).
    """
    normalized: list[NormalizedExercise] = []
    seen_ids: set[str] = set()
    skipped = 0

    for raw in raw_exercises:
        try:
            exercise = _normalize_one(raw)
        except ExerciseValidationError as exc:
            logger.warning("Ejercicio descartado: %s", exc)
            skipped += 1
            continue

        if exercise.source_id in seen_ids:
            raise ExerciseValidationError(
                f"source_id duplicado en el origen: {exercise.source_id}"
            )
        seen_ids.add(exercise.source_id)
        normalized.append(exercise)

    if skipped:
        logger.warning(
            "%d ejercicio(s) descartado(s) de %d", skipped, len(raw_exercises)
        )

    min_expected = len(raw_exercises) * (1 - _MAX_DROP_FRACTION)
    if raw_exercises and len(normalized) < min_expected:
        raise ExerciseValidationError(
            f"caída de más del {_MAX_DROP_FRACTION:.0%} en el conteo: "
            f"{len(raw_exercises)} -> {len(normalized)}. "
            "El formato upstream pudo haber cambiado; revisar antes de publicar."
        )

    normalized.sort(key=lambda e: e.source_id)
    return normalized


def fetch_and_normalize_exercises() -> list[NormalizedExercise]:
    """Descarga y normaliza, sin traducir nombres todavía (eso pega a una
    API externa — ver translate.py — y por eso queda fuera de esta
    función, que es la que prueban los tests sin red)."""
    raw_text = download_text(
        FREE_EXERCISE_DB_JSON_URL, cache_name="free-exercise-db.json"
    )
    raw_exercises = json.loads(raw_text)
    if not isinstance(raw_exercises, list):
        raise ExerciseValidationError("el JSON de origen no es una lista")

    normalized = normalize_exercises(raw_exercises)
    logger.info("Catálogo de ejercicios: %d filas normalizadas", len(normalized))
    return normalized


def attach_spanish_names(
    exercises: list[NormalizedExercise], translations: dict[str, str]
) -> list[NormalizedExercise]:
    """Combina las traducciones de `name` ya obtenidas (por `source_id`)
    en `name_es`. Pura: no llama a ninguna API, por eso es lo que se
    prueba — la llamada real vive en translate.py."""
    return [
        replace(exercise, name_es=translations.get(exercise.source_id))
        for exercise in exercises
    ]
