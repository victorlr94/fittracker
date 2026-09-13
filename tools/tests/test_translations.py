"""Los diccionarios de equipo/músculos son un vocabulario cerrado: un
valor no traducido debe abortar el build, no colarse en inglés en
silencio."""

import pytest

from fittracker_data.translations import translate_equipment, translate_muscles


def test_traduce_equipo_conocido() -> None:
    assert translate_equipment("barbell") == "Barra"


def test_equipo_none_se_preserva() -> None:
    assert translate_equipment(None) is None


def test_equipo_desconocido_lanza() -> None:
    with pytest.raises(KeyError, match="smith machine"):
        translate_equipment("smith machine")


def test_traduce_lista_de_musculos() -> None:
    assert translate_muscles(["chest", "triceps"]) == ["Pecho", "Tríceps"]


def test_lista_vacia_de_musculos() -> None:
    assert translate_muscles([]) == []


def test_musculo_desconocido_lanza() -> None:
    with pytest.raises(KeyError, match="obliques"):
        translate_muscles(["chest", "obliques"])
