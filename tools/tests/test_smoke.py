"""Prueba de humo: confirma que el paquete importa y que pytest/mypy/ruff
están correctamente cableados antes de que exista lógica de ingesta real
(esa llega en las Fases 1 y 2, ver docs/02-roadmap.md)."""

from fittracker_data import main


def test_main_runs_without_error() -> None:
    main()
