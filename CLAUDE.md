# CLAUDE.md — instrucciones de trabajo para FitTracker

App Android personal (Flutter) para registrar comidas y entrenamientos, con un módulo de estimación de porciones por foto usando la API de Claude. Uso personal, offline-first, sin backend. También es pieza de portafolio: la calidad de ingeniería es parte del entregable.

**El usuario es ingeniero con experiencia sólida en Python, SQL y ML, y poca en desarrollo móvil.** Explica las decisiones de Flutter/Dart cuando no sean obvias; no expliques SQL, pandas ni conceptos de ingeniería de datos.

---

## Antes de escribir código

Lee, en este orden, solo lo que aplique a la fase en curso:

| Documento | Cuándo |
|---|---|
| [`docs/02-roadmap.md`](docs/02-roadmap.md) | **Siempre.** Define el alcance cerrado de la fase y su criterio de terminado |
| [`docs/01-modelo-de-datos.md`](docs/01-modelo-de-datos.md) | Al tocar el esquema o cualquier consulta |
| [`docs/00-decisiones.md`](docs/00-decisiones.md) | Al dudar de por qué algo es como es |
| [`docs/03-ingesta-de-datos.md`](docs/03-ingesta-de-datos.md) | Al trabajar en `tools/` o en la siembra del catálogo |
| [`docs/04-modulo-foto.md`](docs/04-modulo-foto.md) | Solo en la Fase 4 |

---

## Fase actual

> **Fase 0 — Cimientos. En curso.**
> Actualiza esta línea al terminar cada fase. Es el primer lugar donde mira una sesión nueva.

Avance de la Fase 0 (2026-09-12):
- [x] Toolchain: Flutter 3.47.4 (`C:\Users\victo\flutter`), Android SDK 36, NDK 28.2.13676358.
- [x] Proyecto Flutter en `app/`, solo Android + iOS. `applicationId = io.github.victorlr94.fittracker` (no cambiar: ver ADR-007).
- [x] Stack validado: `flutter build apk --release --split-per-abi` → arm64 de 14.3 MB.
- [ ] Todo lo demás del alcance de la Fase 0 en `docs/02-roadmap.md` (git, estructura de capas, Drift v1, export/import, keystore, CI, `tools/`).

Nota del entorno local: el `sdkmanager.bat` de estas cmdline-tools delega a `android.exe` y falla cuando Gradle le pide un paquete con `;`. Si Gradle no puede autoinstalar un componente, instálalo a mano con la sintaxis de barra: `android.exe sdk install ndk/<versión>`.

**Regla de oro: una fase a la vez.** No se empieza la siguiente hasta que la actual cumpla su criterio de terminado y la CI esté en verde. Si al implementar la Fase 1 detectas algo de la Fase 2, anótalo en el roadmap y sigue. No lo implementes.

---

## Estructura del repo

```
.
├── CLAUDE.md                    ← este archivo
├── README.md                    ← público: qué es, cómo se instala, licencias
├── docs/                        ← decisiones, modelo de datos, roadmap, ingesta, foto
├── app/                         ← proyecto Flutter
│   ├── lib/
│   │   ├── core/                ← BD (Drift), errores, Result, formato, utilidades
│   │   ├── domain/              ← DART PURO. Cero imports de Flutter o Drift
│   │   │   ├── entities/
│   │   │   ├── services/        ← macros, 1RM, volumen, parseo del modelo
│   │   │   └── repositories/    ← interfaces abstractas
│   │   ├── data/                ← DAOs de Drift, clientes HTTP (USDA, OFF, Claude)
│   │   └── features/            ← UI + providers de Riverpod
│   │       ├── workouts/ meals/ recipes/ photo/ settings/
│   ├── assets/catalog/          ← exercises.json, foods_usda.json, manifest.json
│   └── test/                    ← espejo de lib/; la mayoría en test/domain/
├── tools/                       ← proyecto Python con uv: ingesta y análisis
└── .github/workflows/ci.yml
```

---

## Comandos

Desde `app/`:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # tras tocar esquema o providers
flutter analyze                                            # debe salir limpio
flutter test                                               # debe salir verde
flutter test test/domain/                                  # solo lógica de negocio, rápido
flutter run                                                # dispositivo conectado
flutter build apk --release --split-per-abi                # APKs por arquitectura; el celular usa arm64-v8a
```

Desde `tools/`:

```bash
uv sync
uv run python -m fittracker_data.build_all
uv run pytest
uv run ruff check . && uv run mypy src
```

**Si aparecen errores de compilación incomprensibles tras tocar el esquema o un provider**, casi siempre es código generado desincronizado: `dart run build_runner build --delete-conflicting-outputs`. Verifícalo antes de depurar cualquier otra cosa.

---

## Invariantes (romper cualquiera de estas es un error, no una opción de diseño)

1. **`domain/` no importa Flutter ni Drift.** Si un archivo de `domain/` necesita `package:flutter/...`, está mal ubicado. Es lo que mantiene las pruebas en milisegundos.
2. **Una migración aplicada no se edita.** Hay un APK instalado con datos reales desde la Fase 0. El esquema cambia agregando la versión siguiente, con su prueba de migración.
3. **`meal_entry` guarda una instantánea de macros.** Editar un alimento o una receta **nunca** altera comidas ya registradas.
4. **El upsert del catálogo no toca `is_favorite` ni `user_notes`**, y nunca pisa filas con `source = 'user'`.
5. **Nada de borrado físico en tablas referenciadas.** Se usa `deleted_at`.
6. **El exportador cubre todas las tablas.** Si agregas una tabla al esquema, actualizas exportador e importador **en el mismo commit**.
7. **Secretos fuera del repo.** API key en `flutter_secure_storage`; keystore y `key.properties` en `.gitignore`. Nunca en logs, código ni assets.
8. **Las macros se almacenan por 100 g/ml; los pesos en kg; las fechas de calendario como texto local `'YYYY-MM-DD'`.** Sin excepciones.
9. **Las series `warmup` no cuentan en el volumen**; `normal`, `drop` y `failure` sí.
10. **La salida del modelo de visión es un borrador.** Ningún camino de la UI escribe un `meal_entry` sin confirmación explícita del usuario.

---

## Convenciones

**Dart**
- `flutter analyze` limpio antes de cada commit. Sin `// ignore:` salvo con una razón escrita al lado.
- Entidades de dominio inmutables (`final`, `copyWith`).
- Errores esperables como valores de retorno (`Result`/`Either`), no excepciones. Las excepciones son para fallos de programación.
- Nombres de archivo en `snake_case`, clases en `PascalCase`. Código y comentarios en inglés; textos de la UI en español.

**Python (`tools/`)**
- Ruff + mypy en modo estricto. Ver la skill `python-code-quality`.
- Entorno y dependencias con `uv`; `uv.lock` versionado.

**Pruebas** — la meta no es cobertura, es cubrir lo que rompe en silencio:
- Cálculos de macros y conversiones de porción.
- La instantánea de `meal_entry`.
- Volumen y 1RM (incluido el borde de 1 repetición).
- Corte del día y zona horaria.
- Upsert del catálogo preservando datos del usuario.
- Parseo de respuestas externas: Open Food Facts y el modelo de visión (JSON malformado, valores fuera de rango, campos faltantes).
- Ida y vuelta de exportación → importación.
- Cada migración, con `MigrationHelper` de Drift.

**Git**
- Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- Una rama por fase: `fase-1-entrenamientos`. PR hacia `main` con auto-revisión.
- Tag SemVer al cerrar cada fase: Fase 0 → `v0.1.0`, Fase 1 → `v0.2.0`.
- Nunca commitear: `app/assets/catalog/` generado sin revisar el diff, `tools/data/`, `key.properties`, `*.jks`, datos de Open Food Facts.

---

## Skills del usuario que aplican

| Skill | Cuándo |
|---|---|
| `git-workflow` | Al iniciar el repo, abrir PRs, etiquetar versiones |
| `testing-strategy` | Al diseñar las pruebas de cada fase |
| `project-documentation` | README y ADRs nuevos |
| `python-repro-env` | Al montar `tools/` |
| `python-code-quality` | Al escribir los scripts de ingesta |
| `claude-api` | **Obligatoria** antes de tocar cualquier código que llame a la API de Claude |
| `llm-security` | Fase 4: manejo de la key, validación de la salida |
| `ai-observability` | Fase 4: qué registrar del pipeline de visión |

---

## Al terminar una fase

1. `flutter analyze` y `flutter test` en verde localmente.
2. CI en verde y APK descargable del artifact.
3. APK instalado en el dispositivo real y **usado** según el criterio de terminado (tres sesiones de gimnasio, siete días de comidas, etc.). El criterio es de uso, no de compilación.
4. Marca la fase como terminada en `docs/02-roadmap.md` y actualiza **Fase actual** en este archivo.
5. Si algo del diseño resultó equivocado al implementarlo, escribe el ADR que lo corrige en `docs/00-decisiones.md`. No edites el ADR viejo: márcalo como reemplazado.
6. Tag de versión.

---

## Cómo trabajar con el usuario

- Sé directo sobre los trade-offs. Si algo de lo que pide es innecesario para esta fase o tiene un riesgo que no está viendo, dilo y propón la alternativa; si lo reafirma, impleméntalo completo.
- Antes de un cambio de diseño no trivial, di qué invariante o ADR toca.
- No expandas el alcance de la fase por iniciativa propia. Lo que sobra se anota en el roadmap.
- Los supuestos vigentes están al final de [`docs/00-decisiones.md`](docs/00-decisiones.md). Si uno resulta falso al implementar, corrígelo ahí.
