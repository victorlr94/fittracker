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

> **Fase 2 — Comidas. En curso.**
> Actualiza esta línea al terminar cada fase. Es el primer lugar donde mira una sesión nueva.

**Fase 0 — terminada (2026-09-12).** Repo público en GitHub
(https://github.com/victorlr94/fittracker), CI en verde (Flutter +
Python), APK de release instalado y probado en un dispositivo real.
Detalle completo en el PR #1 y en el historial de `main`. Notas de
entorno que siguen vigentes si vuelves a tocar el toolchain local o CI:
- El `sdkmanager.bat` de las cmdline-tools nuevas delega a `android.exe`
  y falla con paquetes que llevan `;` en el nombre — instalar a mano con
  `android.exe sdk install ndk/<versión>` (sintaxis de barra).
- El compilador incremental de Kotlin se cuelga en este Windows al
  cerrar sus cachés; `kotlin.incremental=false` en
  `android/gradle.properties` es el workaround, ya aplicado.
- En CI, GitHub Actions no permite `secrets` directo en un `if:` de
  step ("Unrecognized named-value") — hay que pasarlo por `env:` a nivel
  de job primero. Y `astral-sh/setup-uv` no publica tags flotantes
  (`v10`); hay que fijar la versión exacta.
- `flutter_local_notifications` exige `isCoreLibraryDesugaringEnabled`
  en `android/app/build.gradle.kts`.
- **`android:uses-permission INTERNET` no lo agrega Flutter por
  defecto.** Sin él, cualquier petición de red falla en el sistema
  operativo sin excepción visible — es fácil no notarlo hasta que
  alguien prueba la app de verdad en un dispositivo. Ya está en el
  manifiesto; si algún módulo de red futuro (USDA, Open Food Facts,
  Claude) parece no conectar nunca, revisar esto primero.
- Cuando `riverpod_generator` falle con `InvalidTypeException` al
  serializar el tipo de retorno de un provider: es una clase que Drift
  genera en un archivo `part` (p. ej. `Routine`, `Exercise`) — escribe
  ese provider a mano (`FutureProvider`/`StreamProvider` normal) en vez
  de con `@riverpod`. Ejemplo: `data/local/repository_providers.dart`.

**Fase 1 — terminada (2026-09-13).** PR #2 fusionado a `main`. Catálogo
de 871 ejercicios (`free-exercise-db`) traducido al español (nombres,
equipo, músculos) vía Claude Opus 5; búsqueda FTS5 con filtros y
favoritos; rutinas con reordenamiento; sesión en vivo con prellenado y
cronómetro de descanso; historial con gráficas de volumen/1RM. Usada de
verdad por el usuario en el gimnasio, con dos bugs reales encontrados y
corregidos en el camino:
- `CatalogSeeder._toCompanion` nunca mapeaba `name_es` al construir la
  fila del upsert — los nombres se quedaban en inglés sin importar
  cuántas veces se resembrara. Ahora hay una prueba
  (`catalog_seeder_test.dart`) que lo habría atrapado antes.
- La lista de rutinas del selector de "Sesión" se cargaba una sola vez
  y nunca se refrescaba entre pestañas — se volvió reactiva
  (`routinesProvider`, escrito a mano por el punto anterior).

Deuda técnica anotada, no bloqueante para seguir: sin pruebas de widget
(la lógica que rompe en silencio ya está probada en `domain`/`data`); el
cronómetro de descanso usa `inexactAllowWhileIdle` (sin permiso de
alarma exacta), puede atrasarse si el teléfono entra en Doze con la
pantalla apagada.

**Regla de oro: una fase a la vez.** No se empieza la siguiente hasta que la actual cumpla su criterio de terminado y la CI esté en verde. Si al implementar una fase detectas algo de la siguiente, anótalo en el roadmap y sigue. No lo implementes.

Avance de la Fase 2 (docs/02-roadmap.md):
- [ ] Ingesta de USDA FoodData Central (Foundation Foods + SR Legacy) → `app/assets/catalog/foods_usda.json`.
- [ ] Siembra versionada de alimentos (mismo patrón que exercise: upsert por `(source, source_id)`, preserva favoritos/notas).
- [ ] Búsqueda FTS + registro por momento del día (desayuno/comida/cena/snack), porciones editables.
- [ ] Totales diarios contra el objetivo (`nutrition_target`).
- [ ] Alimentos propios (crear desde cero o desde etiqueta).
- [ ] Código de barras vía Open Food Facts, con alta manual como *fallback* obligatorio (cobertura mexicana irregular — no es opcional, ver docs/02-roadmap.md).

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
