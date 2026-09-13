"""Diccionarios de traducción para los vocabularios cerrados del
catálogo: equipo y grupos musculares. A mano, no por API — son ~30
términos fijos (verificados contra el dataset real de
`free-exercise-db`) y el resultado es más confiable y revisable en un
diff que una llamada al modelo para algo de cardinalidad tan chica.

Los nombres de ejercicio (871 frases distintas) sí se traducen por API
— ver translate.py.
"""

EQUIPMENT_ES: dict[str, str] = {
    "bands": "Bandas elásticas",
    "barbell": "Barra",
    "body only": "Peso corporal",
    "cable": "Polea",
    "dumbbell": "Mancuerna",
    "e-z curl bar": "Barra Z",
    "exercise ball": "Balón de ejercicio",
    "foam roll": "Rodillo de espuma",
    "kettlebells": "Pesas rusas",
    "machine": "Máquina",
    "medicine ball": "Balón medicinal",
    "other": "Otro",
}

MUSCLE_ES: dict[str, str] = {
    "abdominals": "Abdominales",
    "abductors": "Abductores",
    "adductors": "Aductores",
    "biceps": "Bíceps",
    "calves": "Pantorrillas",
    "chest": "Pecho",
    "forearms": "Antebrazos",
    "glutes": "Glúteos",
    "hamstrings": "Isquiotibiales",
    "lats": "Dorsales",
    "lower back": "Espalda baja",
    "middle back": "Espalda media",
    "neck": "Cuello",
    "quadriceps": "Cuádriceps",
    "shoulders": "Hombros",
    "traps": "Trapecios",
    "triceps": "Tríceps",
}


def translate_equipment(value: str | None) -> str | None:
    """Lanza si aparece un valor de equipo que no está en el diccionario
    — mejor abortar el build que publicar un catálogo a medio traducir
    en silencio (misma filosofía que la validación del 10% en exercises.py)."""
    if value is None:
        return None
    try:
        return EQUIPMENT_ES[value]
    except KeyError as exc:
        raise KeyError(
            f"Sin traducción para el equipo {value!r}; agrégalo a EQUIPMENT_ES"
        ) from exc


def translate_muscles(values: list[str]) -> list[str]:
    try:
        return [MUSCLE_ES[v] for v in values]
    except KeyError as exc:
        raise KeyError(
            f"Sin traducción para el músculo {exc.args[0]!r}; agrégalo a MUSCLE_ES"
        ) from exc
