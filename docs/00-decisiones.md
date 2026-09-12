# Decisiones de arquitectura (ADRs)

Registro de decisiones en formato corto: **contexto → opciones → decisión → consecuencias**.
Una decisión revocada no se borra: se marca como *Reemplazada por ADR-XXX* y se escribe el ADR nuevo.

| ADR | Título | Estado |
|---|---|---|
| [001](#adr-001--stack-móvil-flutter--drift) | Stack móvil: Flutter + Drift | Aceptada |
| [002](#adr-002--base-de-datos-local-y-migraciones) | Base de datos local y migraciones | Aceptada |
| [003](#adr-003--fuentes-de-datos-por-módulo-y-licencias) | Fuentes de datos por módulo y licencias | Aceptada |
| [004](#adr-004--wger-descartado-como-backend) | wger descartado como backend | Aceptada |
| [005](#adr-005--estrategia-del-módulo-de-estimación-por-foto) | Estrategia del módulo de foto | Aceptada |
| [006](#adr-006--arquitectura-en-capas) | Arquitectura en capas | Aceptada |
| [007](#adr-007--respaldo-exportación-y-firma-del-apk) | Respaldo, exportación y firma del APK | Aceptada |
| [008](#adr-008--gestión-de-estado-riverpod) | Gestión de estado: Riverpod | Aceptada |

---

## ADR-001 — Stack móvil: Flutter + Drift

### Contexto

Android es obligatorio. Vienes de Python, SQL y ML, con poca experiencia móvil. La app necesita: base de datos local con migraciones, cámara y lector de código de barras, gráficas simples, llamadas HTTP a APIs externas, y pruebas unitarias sobre lógica de negocio. El proyecto lo mantendremos en sesiones espaciadas, así que la facilidad de retomarlo pesa tanto como la velocidad inicial. iOS es una posibilidad remota.

Un dato del entorno que no depende del stack: en tu máquina no hay JDK ni Android SDK. **Los tres candidatos requieren instalar el toolchain de Android** (~10-15 GB) para producir un APK localmente. Eso no es un criterio de desempate.

### Opciones

| Criterio | Flutter + Drift | Kotlin + Compose + Room | React Native / Expo |
|---|---|---|---|
| **Curva viniendo de Python** | Media. Dart es nuevo pero directo: tipado, sin punteros, sin macros. El modelo mental de widgets se aprende rápido con hot reload. | Alta. No es Kotlin el problema: son Gradle, KSP, Hilt, coroutines y Flow, cuatro sistemas que hay que entender antes de que compile la primera pantalla. | Media-baja si ya sabes JS; alta si no. TypeScript + el modelo de React son dos cosas a la vez. |
| **Velocidad al primer APK funcional** | Alta. `flutter create` → `flutter build apk` funciona de un jalón. | Media. Android Studio da la plantilla, pero cada dependencia nueva es una negociación con Gradle. | Alta con Expo (EAS Build compila en la nube, sin SDK local), baja si sales de Expo (`prebuild` y pierdes la ventaja). |
| **Offline / SQLite** | **Lo mejor de los tres.** Drift genera código desde tu esquema o desde SQL escrito a mano, valida las consultas en tiempo de compilación, y trae utilidades específicas para *probar migraciones* entre versiones. | Muy bueno. Room es maduro, con migraciones y `MigrationTestHelper`. Un poco más verboso. | El más débil. `expo-sqlite` + Drizzle funciona, pero las migraciones son menos maduras y el ecosistema rota más rápido de lo que tú vas a tocar este proyecto. |
| **Cámara y código de barras** | Muy bueno. `camera` + `mobile_scanner` (que por debajo usa ML Kit en Android). | **El mejor.** CameraX + ML Kit directo, sin capa intermedia. | Bueno. `expo-camera` trae escaneo integrado. |
| **Que yo lo mantenga entre sesiones** | Alto. Un solo lenguaje para UI, lógica y datos; un solo archivo de dependencias; errores de compilación legibles. | Medio. Los fallos de Gradle son opacos y consumen sesiones enteras en diagnóstico. | Medio-bajo. El churn del ecosistema JS significa que el proyecto se pudre si lo dejas tres meses. |
| **Puerta a iOS** | Abierta (requiere una Mac para compilar, pero el código sirve). | Cerrada. | Abierta (misma condición de Mac). |
| **Tamaño del APK** | ~15-20 MB de base. | ~5-8 MB. | ~25-30 MB. |

### Decisión

**Flutter + Drift.**

El argumento decisivo es dónde pediste las pruebas: *"cálculo de macros, progresión, parseo de respuestas del modelo"*. En Flutter esa lógica vive en Dart puro, en `domain/`, sin una sola importación de framework. Se corre con `flutter test` en segundos, en tu laptop, sin emulador y sin CI lenta. En Kotlin lo mismo es posible pero requiere disciplina activa para que las clases de dominio no arrastren dependencias de Android; en cuanto una lo hace, ese test necesita Robolectric o un dispositivo y el ciclo se vuelve de minutos en vez de segundos.

El segundo argumento es Drift. Es la única de las tres capas de datos que te deja escribir SQL a mano y te lo valida en compilación, lo cual es exactamente lo que quieres alguien que ya piensa en SQL. Y su soporte de pruebas de migración importa más de lo que parece: la app va a evolucionar por versiones sobre datos reales tuyos que no puedes perder.

El tercero es que un solo lenguaje reduce a la mitad la superficie que tengo que reconstruir mentalmente cada vez que retomamos el proyecto.

### Consecuencias

- Dart es un lenguaje nuevo para ti. Es el costo real de esta decisión. Mitigación: la lógica que te interesa (macros, 1RM, parseo) es Dart puro y se parece más a Python de lo que temes; el framework solo aparece en `features/`.
- APK de ~15-20 MB de base. Irrelevante para uso personal.
- Renunciamos a ML Kit directo. `mobile_scanner` lo envuelve y es suficiente.
- Necesitamos `build_runner` para generar el código de Drift y Riverpod. Es un paso extra (`dart run build_runner build`) que hay que recordar tras editar el esquema. Queda anotado en `CLAUDE.md`.
- Si algún día quieres iOS, el código sirve pero necesitarás una Mac para compilar. No hay forma de evitarlo con ningún stack.

### Pila concreta de paquetes

| Necesidad | Paquete |
|---|---|
| Base de datos | `drift` + `sqlite3_flutter_libs` + `drift_dev` |
| Estado | `flutter_riverpod` + `riverpod_generator` |
| HTTP | `dio` |
| Código de barras | `mobile_scanner` |
| Cámara / galería | `image_picker` + `image` (reescalado) |
| Gráficas | `fl_chart` |
| Almacenamiento seguro | `flutter_secure_storage` |
| Rutas de archivos | `path_provider` |
| Selección de carpeta de export | `file_picker` |

---

## ADR-002 — Base de datos local y migraciones

### Contexto

Todo debe funcionar offline. Los datos son tuyos y deben sobrevivir a cada actualización de la app durante años. Además quieres poder analizarlos en Python después.

### Opciones

1. **SQLite vía Drift** — relacional, SQL, migraciones explícitas.
2. **Isar / ObjectBox** — NoSQL embebido, más rápido de escribir al inicio.
3. **Archivos JSON en disco** — cero infraestructura.

### Decisión

**SQLite vía Drift**, con migraciones numeradas desde la versión 1.

Tus datos son intrínsecamente relacionales (una sesión tiene series que referencian ejercicios; una comida referencia un alimento o una receta que referencia alimentos). Además ya piensas en SQL, y el archivo `.sqlite` resultante lo abres con `pandas.read_sql` sin traducción. Isar te ahorraría una tarde y te costaría eso después.

### Reglas que se aplican desde el día uno

1. **Una migración ya aplicada nunca se edita.** Si el esquema cambia, se agrega la siguiente versión. Esta regla se rompe sola cuando la app ya está instalada en tu celular con datos reales — que es desde la Fase 0.
2. **Cada migración tiene una prueba** con `MigrationHelper` de Drift: se construye la BD en la versión anterior, se inserta una fila, se migra, y se verifica que la fila sigue ahí y correcta.
3. **Búsqueda con FTS5.** Las tablas `food` y `exercise` tienen índices de texto completo. Buscar "pechuga pollo" entre 8,000 alimentos con `LIKE '%...%'` es lento y da malos resultados; FTS5 viene incluido en SQLite y resuelve ambas cosas.
4. **Borrado lógico (`deleted_at`) en tablas que se referencian.** Borrar físicamente un alimento que está en una comida de hace tres meses rompe el historial.

### Consecuencias

- Más ceremonia al inicio que un NoSQL embebido.
- El archivo de BD es directamente analizable en Python, lo cual duplica el valor de portafolio del proyecto.
- `build_runner` debe correrse tras cada cambio de esquema, o el código generado se desincroniza y los errores son confusos.

---

## ADR-003 — Fuentes de datos por módulo y licencias

### Contexto

Necesitamos ejercicios, alimentos genéricos y productos empacados. El repo será público. Las licencias de datos no son un trámite: la de Open Food Facts impone obligaciones reales sobre lo que puedes redistribuir.

### Decisión por módulo

| Módulo | Fuente | Modo de uso | Licencia | Qué obliga |
|---|---|---|---|---|
| Ejercicios | [`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db) | JSON empaquetado en el APK; imágenes desde el CDN del repo, con caché | **Unlicense** (dominio público) | Nada. Se atribuye por cortesía. |
| Alimentos genéricos | [USDA FoodData Central](https://fdc.nal.usda.gov/) — subconjuntos *Foundation Foods* y *SR Legacy* | Descarga masiva, normalizada y empaquetada en el APK | **Dominio público** (obra del gobierno de EE. UU.) | Nada. La API key gratuita solo se usa en los scripts de ingesta, nunca desde la app. |
| Productos con código de barras | [Open Food Facts](https://world.openfoodfacts.org/) | API en línea al escanear; caché local permanente de lo que escaneas | **ODbL 1.0** (base de datos); imágenes CC-BY-SA 3.0 | Atribución visible en la app + *share-alike* sobre bases de datos derivadas que se publiquen. |
| Recetas | Cargadas por ti | — | Tuyas | — |

### Las dos reglas que se derivan de ODbL

1. **Los datos de Open Food Facts nunca se suben al repo.** La caché vive solo en el dispositivo. Mientras no publiques la base derivada, la obligación de *share-alike* no se activa.
2. **La app muestra la atribución.** Una línea en la pantalla de Acerca de: *"Datos de productos de Open Food Facts, bajo ODbL 1.0"*, y la misma línea en el README.

### Descartadas

- **ExerciseDB** (~11k ejercicios) — de pago para uso productivo. Documentada como opción futura si el catálogo de 800 resulta corto. Anota qué te faltó antes de pagar por ella.
- **Spoonacular / Edamam** para recetas — las macros de una receta son la suma de sus ingredientes, y los ingredientes ya los tienes en `food`. Meter una API externa con cuota diaria, atribución obligatoria y macros que en el fondo son estimaciones de otro, para una operación que es una suma local, es complejidad sin retorno. Si alguna vez quieres *descubrir* recetas (no calcularlas), se reevalúa; verifica los límites de sus planes gratuitos en ese momento, porque cambian seguido.

---

## ADR-004 — wger descartado como backend

### Contexto

wger es open source, tiene API REST, catálogo de ejercicios y despliegue en Docker. Pediste evaluarlo como alternativa a construir el módulo de entrenamientos desde cero.

### Decisión

**Descartado como arquitectura.** Se documenta como posible fuente de datos futura.

### Argumento

1. **Rompe el requisito de offline.** wger es un servidor Django. Correrlo en Docker significa que tu celular en el gimnasio depende de una máquina encendida en tu casa y de una VPN o un túnel para alcanzarla. La alternativa —desplegarlo en la nube— contradice "sin backend propio en v1". Un servidor local no es una base de datos local.
2. **Su licencia de datos es peor.** El contenido del catálogo de ejercicios de wger es CC-BY-SA 4.0: copyleft, se propaga a lo que derives de él. `free-exercise-db` es Unlicense, dominio público, sin ataduras. Para un proyecto que quizá algún día sea comercial, la diferencia importa.
3. **El módulo de entrenos no es la parte difícil.** El registro de series y el historial son CRUD sobre tres tablas. Adoptar un servidor completo para evitar escribirlas es cambiar un problema pequeño y tuyo por uno grande y ajeno.

### Consecuencias

- Escribimos el catálogo y el registro nosotros. Es trabajo, pero es trabajo predecible.
- Si el catálogo de 800 ejercicios resulta insuficiente, la API pública de wger sigue disponible como *fuente de ingesta* (respetando CC-BY-SA para lo que se derive de ahí y marcando esas filas con `source = 'wger'`). Eso es un script de Python, no una decisión de arquitectura.

---

## ADR-005 — Estrategia del módulo de estimación por foto

### Contexto

Quieres estimar calorías desde una foto usando un modelo de visión. El riesgo real no es la identificación del alimento —los modelos actuales reconocen "arroz, pollo, frijoles" bastante bien— sino la **porción**: una foto 2D no contiene volumen ni densidad. Un modelo puede decir "150 g de arroz" con una redacción segura y estar 60 % equivocado.

### Decisión

Cuatro reglas, y ninguna es negociable:

1. **La salida del modelo es una sugerencia editable, nunca un registro.** No existe un camino en la UI donde una estimación se guarde sin que la hayas revisado ítem por ítem. El botón dice "Revisar", no "Guardar".
2. **La estimación del modelo y tu corrección se guardan por separado y para siempre**, en `photo_estimate` y `photo_estimate_item`. La comida registrada apunta a tu versión corregida; la del modelo queda intacta al lado.
3. **La confianza por ítem se muestra en la UI**, y los ítems de baja confianza aparecen resaltados para que los mires primero.
4. **La API key vive en `flutter_secure_storage`** (respaldado por el Keystore de Android), capturada desde una pantalla de ajustes. Nunca en el repo, nunca en el APK, nunca en un archivo `.env` empaquetado.

### Por qué esto vale más que la feature

La regla 2 convierte cada foto que registras en una fila de un dataset etiquetado por ti: *estimación del modelo vs. verdad*. Después de un par de meses de uso tendrás material para medir MAE en gramos, tasa de identificación y calibración de la confianza reportada — y para comparar modelos sobre el mismo set. Eso es un caso de estudio de evaluación de LLMs con datos propios, que es bastante más interesante en un portafolio de AI Engineering que "le puse visión a mi app".

### Consecuencias

- La UI de confirmación es la pantalla más cara de la Fase 4. Es donde está el valor; no se recorta.
- Hay costo monetario por uso (ver [`04-modulo-foto.md`](04-modulo-foto.md)). La pantalla de ajustes muestra el acumulado del mes para que no sea una sorpresa.
- Requiere internet. Es el único módulo que lo requiere, y su fallo nunca bloquea el registro manual.

---

## ADR-006 — Arquitectura en capas

### Contexto

Pediste una capa de acceso a datos aislada, por si algún día la app se vuelve comercial. También pediste pruebas de lógica de negocio. Resulta que ambas cosas se resuelven con la misma decisión.

### Decisión

Tres capas, con dependencias en una sola dirección: `features → domain ← data`.

```
app/lib/
├── core/            Utilidades transversales: BD (Drift), errores, Result, formato
├── domain/          DART PURO. Cero importaciones de Flutter.
│   ├── entities/    Modelos inmutables: Food, Recipe, WorkoutSet, ...
│   ├── services/    Funciones puras: macros, 1RM, volumen, parseo del modelo
│   └── repositories/ Interfaces abstractas (contratos), sin implementación
├── data/            Implementaciones: DAOs de Drift, clientes HTTP (USDA, OFF, Claude)
└── features/        UI + providers de Riverpod, una carpeta por módulo
    ├── workouts/
    ├── meals/
    ├── recipes/
    └── photo/
```

La regla que hace que funcione: **`domain/` no importa nada de Flutter ni de Drift.** Si un archivo de `domain/` necesita `package:flutter/...`, está mal ubicado.

### Consecuencias

- Los tests de `domain/` son Dart puro: corren en milisegundos, sin emulador. Ahí vive todo lo que pediste probar.
- Cambiar SQLite por otra cosa, o agregar sincronización con un servidor, toca `data/` y nada más. Eso es lo que mantiene abierta la puerta comercial sin diseñar para ella hoy.
- Cuesta un poco de ceremonia: una interfaz en `domain/repositories/` por cada repositorio, más su implementación en `data/`. Con cuatro módulos es un costo pequeño y acotado.

---

## ADR-007 — Respaldo, exportación y firma del APK

### Contexto

Dos riesgos que no estaban en el planteamiento original y que muerden una sola vez, fuerte:

**Pérdida de datos.** Un APK instalado a mano, sin cuenta ni nube. Si se te pierde el celular, lo restableces, o desinstalas la app, se va todo tu historial. Un año de entrenamientos no se reconstruye.

**Pérdida del keystore.** Android exige que todas las versiones de una app estén firmadas con la misma llave. Si pierdes el keystore, no puedes actualizar la app instalada: tienes que desinstalarla —perdiendo los datos— y reinstalar desde cero.

### Decisión

**Ambas mitigaciones entran en la Fase 0, no después.**

1. **Exportación e importación completas desde la Fase 0.** JSON (fidelidad total, para reimportar) y CSV por tabla (para pandas). Y la prueba que importa: exportar → borrar la BD → importar → comparar. Si ese ciclo no es exacto, el respaldo es decorativo.
2. **Exportación automática semanal** a una carpeta que elijas (típicamente una sincronizada con Drive), silenciosa, conservando las últimas 8 copias.
3. **`android:allowBackup="false"`** en el manifiesto. El respaldo automático de Android sobre una app sideloaded es impredecible; mejor un mecanismo explícito que uno que crees que existe.
4. **Keystore generado en la Fase 0**, respaldado **fuera del repo** (gestor de contraseñas o carpeta cifrada), y cargado en GitHub Actions como secreto (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`). El archivo `key.properties` va en `.gitignore` desde el primer commit.

### Consecuencias

- La Fase 0 se alarga. A cambio, la Fase 1 puede generar datos reales sin que estés arriesgando nada.
- El formato de exportación se vuelve un contrato: al cambiar el esquema, el exportador y el importador se actualizan en el mismo commit. Queda como regla en `CLAUDE.md`.

---

## ADR-008 — Gestión de estado: Riverpod

### Contexto

Flutter no impone una solución de estado. Las opciones vivas son `setState` a secas, Provider, Riverpod y BLoC.

### Decisión

**Riverpod** (`flutter_riverpod` + `riverpod_generator`).

`setState` no alcanza en cuanto hay una sesión de entrenamiento en curso que sobrevive a la navegación entre pantallas. BLoC es más ceremonia de la que este proyecto justifica. Riverpod está en el punto medio: los providers se declaran con una anotación, se inyectan por tipo, se sobreescriben trivialmente en tests, y su documentación es la mejor del ecosistema —lo cual importa cuando tú lo lees por primera vez y cuando yo lo retomo tres semanas después.

### Consecuencias

- Otro generador de código en `build_runner`. Ya está ahí por Drift, así que el costo marginal es cero.
- Convención: un provider por caso de uso, no un provider gigante por pantalla.

---

## Supuestos vigentes

Decisiones tomadas sin consultarte, porque un supuesto razonable bastaba. Si alguno resulta falso, se corrige con una migración.

| # | Supuesto | Si cambia |
|---|---|---|
| S-1 | `minSdk = 26` (Android 8.0), `targetSdk` = última estable | Se ajusta en `build.gradle`; sin impacto en datos |
| S-2 | Sistema métrico: kg, g, ml | Se agrega conversión en la capa de presentación; los datos siempre se guardan en métrico |
| S-3 | UI en español; nombres de ejercicios traducidos en `name_es` conservando `name` original | Ya está contemplado en el esquema |
| S-4 | Un objetivo nutricional vigente a la vez, con historial (`effective_from`) | Objetivos por día de la semana requerirían una tabla nueva, no una migración destructiva |
| S-5 | Series planas con `set_type` (`normal`/`warmup`/`drop`/`failure`) + `superset_group` opcional | Cubre supersets y dropsets sin jerarquía; si necesitas más, se extiende el enum |
| S-6 | El día nutricional corta a medianoche en la zona horaria del dispositivo | El corte se guarda explícito en cada fila, así que un cambio de regla no reinterpreta el historial |
| S-7 | Eres el único usuario; no hay concepto de cuenta | Es justo lo que el ADR-006 mantiene barato de cambiar |
