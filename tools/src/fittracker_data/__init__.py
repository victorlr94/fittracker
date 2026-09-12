"""Ingesta y análisis de datos externos para FitTracker.

Ver docs/03-ingesta-de-datos.md. Los scripts de descarga y transformación
por fuente (`exercises.py`, `usda.py`, ...) llegan en las fases 1 y 2 del
roadmap (docs/02-roadmap.md); este paquete solo trae el esqueleto —
configuración de Ruff/mypy y la estructura de carpetas— en la Fase 0.
"""

import logging

logger = logging.getLogger(__name__)


def main() -> None:
    logger.info("fittracker-data: aún no hay comandos de ingesta (Fase 0).")
