# Roadmap por fases

Regla de trabajo: **una fase a la vez**. Una fase empieza cuando la anterior cumple su criterio de terminado y su CI está en verde. Nada de "avanzo un poco de la 2 mientras termino la 1": el propósito de las fases es que cada sesión tenga un alcance cerrado y verificable.

| Fase | Alcance | Migración | Estado |
|---|---|---|---|
| 0 | Cimientos: toolchain, repo, CI, BD, export/import, firma | v1 | **Terminada** |
| 1 | Entrenamientos | — | En curso |
| 2 | Comidas | — | Pendiente |
| 3 | Recetas | — | Pendiente |
| 4 | Estimación por foto | v2 | Pendiente |

---

## Fase 0 — Cimientos

Lo más aburrido y lo más importante. Todo lo que es caro de retrofitear.

### Alcance

1. **Toolchain**: JDK 17, Android SDK (línea de comandos o Android Studio), Flutter estable. `flutter doctor` sin errores rojos.
2. **Repo**: `git init`, repo público en GitHub, `.gitignore` (que incluya `key.properties`, `*.jks`, `.env`, `build/`, `.dart_tool/`), README inicial con las atribuciones de licencias del [ADR-003](00-decisiones.md#adr-003--fuentes-de-datos-por-módulo-y-licencias).
3. **Esqueleto**: proyecto Flutter en `app/` con la estructura de capas del [ADR-006](00-decisiones.md#adr-006--arquitectura-en-capas). Riverpod y navegación mínima entre pestañas vacías.
4. **Base de datos**: Drift con la **migración v1 completa** (todas las tablas salvo las de foto), incluidas las tablas FTS5 y sus triggers, más su prueba de migración.
5. **Exportación e importación**: JSON completo (reimportable) y CSV por tabla (para pandas). Con la prueba de ida y vuelta.
6. **Exportación automática semanal** a una carpeta elegida, conservando las últimas 8 copias.
7. **Firma**: keystore generado, respaldado fuera del repo, `key.properties` ignorado, secretos cargados en GitHub.
8. **CI** (`.github/workflows/ci.yml`): `flutter analyze` → `flutter test` → `flutter build apk --release` firmado, publicado como artifact descargable.
9. **Proyecto Python** en `tools/` inicializado con `uv`, con Ruff y mypy configurados (aunque todavía no haya scripts de ingesta).

### Criterio de terminado

- [ ] `flutter analyze` sin advertencias y `flutter test` en verde, localmente y en CI.
- [ ] El APK firmado sale de GitHub Actions, se instala en tu celular y abre.
- [ ] La app crea la base de datos en el primer arranque; se comprueba con un `SELECT` desde `adb`.
- [ ] Ciclo de respaldo verificado **a mano en el dispositivo**: exportar → desinstalar la app → reinstalar → importar → los datos están idénticos.
- [ ] El keystore está respaldado en un segundo lugar fuera del repo. Sin esto, la fase no está terminada.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| El toolchain de Android consume la sesión completa | Es ~15 GB de descarga. Presupuéstalo aparte; no lo mezcles con trabajo de código. |
| `build_runner` desincronizado produce errores incomprensibles | Regla en `CLAUDE.md`: ante cualquier error raro tras tocar el esquema, `dart run build_runner build --delete-conflicting-outputs`. |
| Firmar en CI mal configurado publica un APK sin firmar o con llave de depuración | El workflow falla explícitamente si faltan los secretos, en vez de caer al modo debug. |
| Diseñar el formato de exportación "para después" | Se define y prueba ahora. Cambiarlo con un año de datos dentro es mucho peor. |

### Qué se prueba

- Migración v1: la BD se crea desde cero con el esquema esperado.
- Exportación → importación: ciclo sin pérdida, incluyendo `NULL`, acentos, decimales y fechas.
- El exportador refleja todas las tablas: una prueba que falla si se agrega una tabla al esquema y no al exportador.

---

## Fase 1 — Entrenamientos

### Alcance

1. **Siembra del catálogo** desde `assets/catalog/exercises.json` en el primer arranque, con upsert por `(source, source_id)`.
2. **Búsqueda y filtros**: FTS por nombre; filtros por músculo, equipo y nivel.
3. **Ficha de ejercicio**: instrucciones paso a paso, músculos, equipo, e imágenes descargadas bajo demanda con caché en disco. Ajuste de "precargar todas las imágenes por WiFi".
4. **Rutinas**: crear, editar y reordenar plantillas con series/reps/RPE/descanso objetivo.
5. **Sesión en vivo**: iniciar desde una rutina o libre; marcar serie por serie; prellenado con lo que hiciste la última vez en ese ejercicio; cronómetro de descanso con notificación; la sesión sobrevive a que cierres la app.
6. **Historial y progresión**: lista de sesiones; por ejercicio, gráficas de volumen por sesión y 1RM estimado en el tiempo.

### Criterio de terminado

- [ ] Registraste **tres sesiones reales en el gimnasio** con la app, sin abrir notas ni otra app.
- [ ] El catálogo busca y filtra con menos de 200 ms de respuesta.
- [ ] La sesión en curso sobrevive a cerrar la app y a que Android mate el proceso.
- [ ] Las gráficas de un ejercicio con al menos tres sesiones se ven correctas y coinciden con un cálculo a mano.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| La sesión en vivo es la pantalla más compleja de toda la app | Se ataca primero, con el estado de sesión persistido en la BD tras **cada** serie, no al cerrar. Si el proceso muere, no se pierde nada. |
| Las imágenes bajo demanda fallan en el gimnasio sin señal | Las instrucciones de texto siempre están offline; la imagen es complementaria. El botón de precarga por WiFi existe por esto. |
| Nombres de ejercicios en inglés estorban al usar | `name_es` se llena para tus ejercicios frecuentes; no hace falta traducir 800. |
| El cronómetro de descanso no suena con la app en segundo plano | Notificación local programada, no un `Timer` en memoria. Probar con la pantalla apagada. |

### Qué se prueba

- **Volumen**: las series `warmup` se excluyen; `normal`, `drop` y `failure` cuentan. Es el error silencioso clásico.
- **1RM estimado**: Epley y Brzycki, incluido el borde de 1 repetición (donde las fórmulas deben devolver el peso tal cual y no dividir entre cero).
- Agregación de volumen por sesión y por semana, con series de distintos ejercicios mezcladas.
- Prellenado: dada una serie histórica, la siguiente sesión propone el valor correcto.
- Upsert del catálogo: reejecutar la siembra **no** duplica filas ni pisa `is_favorite` ni `user_notes`.
- Sesión activa: no se pueden abrir dos a la vez.

---

## Fase 2 — Comidas

La fase más grande. Aquí está el modelo de datos que hace barata la Fase 3.

### Alcance

1. **Siembra nutricional** desde `assets/catalog/foods_usda.json` (Foundation + SR Legacy), con sus porciones.
2. **Búsqueda FTS** con acentos normalizados, ordenada por uso reciente y favoritos.
3. **Registro diario**: cuatro momentos, porciones editables por gramos o por porción nombrada, reordenar y duplicar entradas, copiar un día entero al siguiente.
4. **Totales diarios** contra el objetivo vigente, con anillos o barras por macro.
5. **Alimentos propios**: crear desde cero o a partir de una etiqueta nutricional; definir porciones propias.
6. **Objetivos**: pantalla de configuración que escribe una fila nueva en `nutrition_target` con `effective_from`.
7. **Código de barras**: escáner con `mobile_scanner`, consulta a Open Food Facts, caché local permanente del producto, y **fallback obligatorio** a "crear alimento desde la etiqueta" con el código ya prellenado cuando no aparece.
8. **Atribución de Open Food Facts** visible en la pantalla de Acerca de.

### Criterio de terminado

- [ ] Registraste **siete días seguidos** de comidas reales con la app.
- [ ] Escaneaste al menos cinco productos mexicanos: los que existen en Open Food Facts se guardan solos, los que no te llevan al alta manual sin fricción.
- [ ] Creaste al menos tres alimentos propios con porciones tuyas.
- [ ] Los totales del día cuadran con una suma hecha a mano.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| **La cobertura de Open Food Facts en México es irregular** | El fallback manual no es opcional, es parte del alcance. Si escanear falla la mitad de las veces y te deja tirado, abandonas la app en una semana. |
| Registrar comida es tedioso y por eso se abandonan estas apps | "Copiar día anterior", "repetir comida" y orden por uso reciente. Tres atajos que valen más que cualquier feature nueva. |
| USDA con 8,000 alimentos genéricos en inglés es difícil de buscar en español | `name_es` se llena para lo que uses seguido; los alimentos propios cubren el resto. Se acepta fricción inicial decreciente. |
| Datos de Open Food Facts incompletos (producto sin macros) | Validar al guardar; si faltan macros, ir al alta manual con lo que sí llegó prellenado. |

### Qué se prueba

- Conversión porción → gramos → macros, incluidos `base_unit = 'ml'` y cantidades fraccionarias.
- **La instantánea**: registrar una comida, luego editar el alimento origen, y verificar que la comida registrada **no cambió**.
- Totales diarios: suma por macro, con entradas de alimento y de receta mezcladas.
- **Corte del día**: una comida registrada a las 23:50 pertenece a ese día y no al siguiente, incluso con el dispositivo en otra zona horaria.
- Objetivo vigente: dado un `log_date`, se elige la fila correcta de `nutrition_target` (incluida la frontera exacta de `effective_from`).
- Parseo de la respuesta de Open Food Facts: producto sin macros, con macros por porción en vez de por 100 g, con campos faltantes.
- Upsert del catálogo nutricional: no pisa alimentos propios ni rompe referencias desde `meal_entry`.

---

## Fase 3 — Recetas

Pequeña, porque la Fase 2 hizo el trabajo pesado.

### Alcance

1. CRUD de recetas: nombre, porciones, ingredientes (buscados en `food`), pasos ordenados, imagen desde galería o cámara.
2. Macros por porción calculadas y mostradas en vivo mientras editas los ingredientes.
3. Registrar `n` porciones de una receta como `meal_entry`, con su instantánea de macros.
4. Escalar una receta (de 4 a 6 porciones) recalculando ingredientes.

### Criterio de terminado

- [ ] Capturaste **tres recetas que de verdad cocinas** y registraste porciones de ellas.
- [ ] Las macros por porción coinciden con un cálculo a mano en hoja de cálculo.
- [ ] Editar una receta no altera las comidas ya registradas de ella.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| Pérdidas de cocción (el arroz absorbe agua; la carne pierde peso) hacen que las macros por porción se desvíen | Campo opcional de **peso final cocinado**: si lo llenas, las porciones se calculan sobre el peso real en vez de la suma de ingredientes crudos. Es la diferencia entre una estimación decente y una mala. |
| Acumular recetas que nunca cocinas | Solo se capturan las que ya haces. La app no es un recetario. |

### Qué se prueba

- Suma de macros de ingredientes y división entre porciones, con redondeo.
- Escalado de receta: proporciones exactas y sin deriva acumulada.
- Ajuste por peso final cocinado.
- Registrar una porción crea un `meal_entry` con instantánea correcta.
- Una receta sin ingredientes o con `servings = 0` se rechaza con un mensaje claro, no con una división entre cero.

---

## Fase 4 — Estimación por foto

Diseño completo en [`04-modulo-foto.md`](04-modulo-foto.md).

### Alcance

1. **Ajustes**: captura de la API key en `flutter_secure_storage`, selección de modelo, y costo acumulado del mes.
2. **Migración v2**: `photo_estimate` y `photo_estimate_item`.
3. **Captura**: foto desde cámara o galería, reescalada a ~1024 px de lado largo antes de enviarse.
4. **Llamada al modelo** por HTTP con salida estructurada, timeout y reintentos acotados.
5. **Pantalla de confirmación**: cada ítem con su etiqueta, gramos y confianza; editar, eliminar y agregar ítems; cruce automático contra `food` con opción de corregir el alimento a mano.
6. **Guardado del par**: la estimación del modelo queda intacta, tu corrección genera los `meal_entry`.
7. **Notebook de evaluación** en `tools/analysis/` que lee el export y calcula las métricas.

### Criterio de terminado

- [ ] Veinte fotos reales procesadas y corregidas por ti.
- [ ] El notebook produce las métricas de [`04-modulo-foto.md`](04-modulo-foto.md) sobre esas veinte.
- [ ] Ningún camino de la UI guarda una estimación sin que la hayas revisado.
- [ ] La app funciona completa sin API key configurada: el módulo simplemente no aparece.
- [ ] Un fallo de red o un JSON inválido muestran un mensaje claro y te dejan registrar a mano.

### Riesgos

| Riesgo | Mitigación |
|---|---|
| **La estimación de gramos será mala.** Una foto no contiene volumen ni densidad | Es un supuesto del diseño, no una sorpresa. La UI trata todo como borrador y la confianza por ítem dirige tu atención. El objetivo es ahorrarte tecleo, no adivinar tu almuerzo. |
| Costo por uso sin control | Costo acumulado del mes visible en ajustes; reintentos acotados; la imagen se reescala antes de enviarse. |
| El cruce automático contra `food` empareja mal ("arroz" → "arroz inflado") | El cruce es una sugerencia con su `match_score` guardado; corregir el alimento es un tap. `match_method` registra cómo se emparejó, para poder medir después qué tan bien funciona. |
| Fuga de la API key | Nunca en el repo, nunca en el APK, nunca en logs. La prueba: `grep` del APK descomprimido no debe encontrarla. |
| Guardar fotos de comida indefinidamente llena el almacenamiento | Ajuste de retención: conservar las últimas N fotos; las filas de estimación se conservan siempre (pesan poco y son el dataset). |

### Qué se prueba

- **Parseo de la respuesta**, que es donde pediste pruebas explícitamente: JSON válido, JSON malformado, arreglo vacío, gramos negativos, confianza fuera de `[0,1]`, campos inesperados, y respuesta truncada. Ninguno de esos casos debe escribir en la BD ni tumbar la app.
- Cálculo del costo a partir de los tokens reportados por la API.
- Mapeo estimación → `meal_entry`: las cuatro acciones (`accepted`, `edited`, `removed`, `added`) producen las filas correctas.
- Las consultas de evaluación sobre un conjunto de datos sintético con resultados conocidos.
- Migración v1 → v2 sin pérdida de datos.

---

## Lo que deliberadamente no está en el roadmap

Para que no se cuele por la puerta de atrás:

- Sincronización en la nube, cuentas de usuario, multi-dispositivo.
- Integración con Google Fit / Health Connect / wearables.
- Planificación de comidas, lista de súper, recetas sugeridas por IA.
- Seguimiento de peso corporal y medidas con gráficas propias (hoy solo `bodyweight_kg` por sesión). Candidato razonable para una v2 según lo que necesites al usarla.
- Widgets, notificaciones de recordatorio, temas personalizables.

Si al usar la app algo de esto resulta necesario de verdad, entra como fase nueva con su ADR. La lista está aquí para que la decisión sea consciente y no por impulso a media implementación.
