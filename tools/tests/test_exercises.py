"""Pruebas de la normalización del catálogo de ejercicios. Todas operan
sobre datos sintéticos en memoria — nada de red aquí (ver
docs/03-ingesta-de-datos.md § Validaciones)."""

import pytest

from fittracker_data.exercises import (
    ExerciseValidationError,
    attach_spanish_names,
    normalize_exercises,
)

RAW_BENCH_PRESS = {
    "id": "Barbell_Bench_Press",
    "name": "Barbell Bench Press",
    "force": "push",
    "level": "intermediate",
    "mechanic": "compound",
    "equipment": "barbell",
    "primaryMuscles": ["chest"],
    "secondaryMuscles": ["shoulders", "triceps"],
    "instructions": ["Lie on the bench.", "Press the bar up."],
    "category": "strength",
    "images": ["Barbell_Bench_Press/0.jpg", "Barbell_Bench_Press/1.jpg"],
}


def _raw(**overrides: object) -> dict[str, object]:
    return {**RAW_BENCH_PRESS, **overrides}


def test_normaliza_un_ejercicio_valido() -> None:
    [exercise] = normalize_exercises([RAW_BENCH_PRESS])

    assert exercise.source == "free-exercise-db"
    assert exercise.source_id == "Barbell_Bench_Press"
    assert exercise.name == "Barbell Bench Press"
    assert exercise.primary_muscles == ["Pecho"]  # traducido (translations.py)
    assert exercise.instructions == ["Lie on the bench.", "Press the bar up."]
    assert exercise.image_urls == [
        "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/0.jpg",
        "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/1.jpg",
    ]


def test_campos_nulos_del_origen_se_preservan_como_none() -> None:
    # equipment/force/mechanic vienen null en ~9% del dataset real
    # (verificado contra el JSON de origen); no deben tumbar el build.
    raw = _raw(id="Adductor_Groin", equipment=None, force=None, mechanic=None)
    [exercise] = normalize_exercises([raw])

    assert exercise.equipment is None
    assert exercise.force is None
    assert exercise.mechanic is None


def test_descarta_ejercicio_sin_instrucciones_sin_abortar_el_build() -> None:
    # Un solo descarte entre muchos válidos: bajo el umbral del 10% que
    # dispara el aborto del build (probado aparte, abajo).
    sin_instrucciones = _raw(id="Roto", instructions=[])
    validos = [_raw(id=f"Valido_{i}") for i in range(10)]

    result = normalize_exercises([sin_instrucciones, *validos])

    assert "Roto" not in [e.source_id for e in result]
    assert len(result) == 10


def test_rechaza_source_id_duplicado() -> None:
    with pytest.raises(ExerciseValidationError, match="duplicado"):
        normalize_exercises([RAW_BENCH_PRESS, RAW_BENCH_PRESS])


def test_aborta_si_se_descarta_mas_del_10_por_ciento() -> None:
    validos = [_raw(id=f"Valido_{i}") for i in range(9)]
    invalidos = [_raw(id=f"Invalido_{i}", instructions=[]) for i in range(2)]

    with pytest.raises(ExerciseValidationError, match="caída de más"):
        normalize_exercises(validos + invalidos)


def test_orden_de_salida_es_estable_por_source_id() -> None:
    raws = [_raw(id="Z_ultimo"), _raw(id="A_primero"), _raw(id="M_medio")]

    result = normalize_exercises(raws)

    assert [e.source_id for e in result] == ["A_primero", "M_medio", "Z_ultimo"]


def test_attach_spanish_names_combina_por_source_id() -> None:
    [exercise] = normalize_exercises([RAW_BENCH_PRESS])
    translations = {"Barbell_Bench_Press": "Press de banca con barra"}

    [result] = attach_spanish_names([exercise], translations)

    assert result.name_es == "Press de banca con barra"
    assert result.name == "Barbell Bench Press"  # el original no se toca


def test_attach_spanish_names_sin_traduccion_deja_none() -> None:
    [exercise] = normalize_exercises([RAW_BENCH_PRESS])

    [result] = attach_spanish_names([exercise], translations={})

    assert result.name_es is None
