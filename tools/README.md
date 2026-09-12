# fittracker-data

Proyecto Python (gestionado con [uv](https://docs.astral.sh/uv/)) para la
ingesta y el análisis de datos externos de FitTracker. Diseño completo en
[`../docs/03-ingesta-de-datos.md`](../docs/03-ingesta-de-datos.md).

**Estado (Fase 0):** solo el esqueleto — configuración de Ruff/mypy y
estructura de carpetas. Los scripts de descarga por fuente
(`exercises.py` en la Fase 1, `usda.py` en la Fase 2) todavía no existen.

## Estructura

```
tools/
├── src/fittracker_data/   # paquete instalable; mypy strict aquí
├── tests/                 # pytest
├── analysis/              # notebooks de exploración/evaluación (Fase 4)
└── data/
    ├── raw/                # descargas crudas — NO se versiona
    └── interim/            # intermedios — NO se versiona
```

## Comandos

```bash
uv sync                              # entorno desde el lockfile
uv run pytest                        # pruebas
uv run ruff check . && uv run ruff format --check .
uv run mypy src/
```

Una vez que existan los scripts de ingesta (Fases 1 y 2):

```bash
uv run python -m fittracker_data.build_all
```
