"""Traducción de los 871 nombres de ejercicio (inglés -> español) vía la
API de Claude. A diferencia de equipo/músculos (vocabulario cerrado, ver
translations.py), aquí son 871 frases distintas — sí vale la pena un
modelo en vez de un diccionario a mano.

Se manda en lotes (no los 871 de un jalón: la salida entera excedería
cómodamente el límite seguro de max_tokens sin streaming) y se cachea en
disco por source_id para no volver a pagar por nombres ya traducidos en
corridas futuras del pipeline.
"""

from __future__ import annotations

import json
import logging

from anthropic import Anthropic
from pydantic import BaseModel

from fittracker_data.config import DATA_INTERIM_DIR

logger = logging.getLogger(__name__)

_MODEL = "claude-opus-5"
_BATCH_SIZE = 150
_CACHE_PATH = DATA_INTERIM_DIR / "exercise_translations_es.json"

_SYSTEM_PROMPT = (
    "Traduces nombres cortos de ejercicios de gimnasio del inglés al "
    "español de México, usando la terminología real que se usa en un "
    "gimnasio — no una traducción literal palabra por palabra cuando el "
    "término técnico en español es distinto. Ejemplos: 'Barbell Bench "
    "Press' -> 'Press de banca con barra'; 'Lat Pulldown' -> 'Jalón al "
    "pecho en polea alta'; 'Seated Cable Row' -> 'Remo sentado en "
    "polea'; 'Standing Calf Raise' -> 'Elevación de talones de pie'. "
    "Devuelve EXACTAMENTE un elemento de salida por cada id de entrada, "
    "preservando el id sin cambios."
)


class _TranslatedExercise(BaseModel):
    id: str
    name_es: str


class _TranslationBatch(BaseModel):
    translations: list[_TranslatedExercise]


def _load_cache() -> dict[str, str]:
    if _CACHE_PATH.exists():
        return dict(json.loads(_CACHE_PATH.read_text(encoding="utf-8")))
    return {}


def _save_cache(cache: dict[str, str]) -> None:
    DATA_INTERIM_DIR.mkdir(parents=True, exist_ok=True)
    _CACHE_PATH.write_text(
        json.dumps(cache, indent=2, ensure_ascii=False, sort_keys=True),
        encoding="utf-8",
    )


def _translate_batch(client: Anthropic, batch: list[tuple[str, str]]) -> dict[str, str]:
    payload = "\n".join(f"{source_id}\t{name}" for source_id, name in batch)
    response = client.messages.parse(
        model=_MODEL,
        max_tokens=16000,
        system=_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": payload}],
        output_format=_TranslationBatch,
    )
    parsed = response.parsed_output
    assert parsed is not None  # output_format garantiza una salida válida
    result = {t.id: t.name_es for t in parsed.translations}

    missing = {source_id for source_id, _ in batch} - result.keys()
    if missing:
        logger.warning(
            "Sin traducción para %d ejercicio(s): %s", len(missing), sorted(missing)
        )
    return result


def translate_exercise_names(items: list[tuple[str, str]]) -> dict[str, str]:
    """`items`: lista de (source_id, name). Devuelve {source_id: name_es}
    para los que se pudieron traducir (los que fallen simplemente no
    aparecen — se quedan en inglés, no abortan el build)."""
    cache = _load_cache()
    pending = [(sid, name) for sid, name in items if sid not in cache]

    if pending:
        client = Anthropic()
        batches = [
            pending[i : i + _BATCH_SIZE] for i in range(0, len(pending), _BATCH_SIZE)
        ]
        for i, batch in enumerate(batches, start=1):
            logger.info(
                "Traduciendo lote %d/%d (%d ejercicios)", i, len(batches), len(batch)
            )
            cache.update(_translate_batch(client, batch))
            _save_cache(cache)  # progreso parcial, por si un lote falla a medias
    else:
        logger.info("Traducciones de ejercicios: todo en caché, sin llamadas nuevas")

    return {sid: cache[sid] for sid, _ in items if sid in cache}
