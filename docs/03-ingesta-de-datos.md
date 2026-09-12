# Ingesta de datos externos

Cómo se descargan, transforman, validan y cargan los datasets, y —lo más importante— cómo se actualizan sin tocar tus datos.

La regla que gobierna todo el documento: **los scripts de Python producen archivos; la app los consume.** Nunca hay una conexión entre tu máquina y la base de datos del celular. El artefacto intermedio es un JSON versionado que vive en el repo.

```
Internet  ──►  tools/ (Python + uv)  ──►  app/assets/catalog/*.json  ──►  APK  ──►  upsert en SQLite
              descarga, normaliza,          revisable en el diff            siembra al arrancar
              valida                        del commit                      si cambió la versión
```

---

## Estructura del proyecto de datos

```
tools/
├── pyproject.toml                  # gestionado con uv
├── uv.lock                         # versionado: reproducibilidad
├── src/fittracker_data/
│   ├── config.py                   # rutas, URLs, constantes
│   ├── download.py                 # descarga con caché en data/raw/
│   ├── exercises.py                # free-exercise-db  → exercises.json
│   ├── usda.py                     # USDA FDC          → foods_usda.json
│   ├── validate.py                 # controles de calidad, compartidos
│   ├── manifest.py                 # versión, conteos, checksums, licencias
│   └── build_all.py                # punto de entrada único
├── analysis/                       # notebooks sobre tus exports (Fase 4)
├── tests/
└── data/
    ├── raw/                        # descargas crudas — EN .gitignore
    └── interim/                    # intermedios — EN .gitignore
```

Salida, y lo único que se versiona del pipeline:

```
app/assets/catalog/
├── exercises.json
├── foods_usda.json
└── manifest.json
```

`data/raw/` no se versiona: son cientos de MB y se reconstruyen con un comando. `uv.lock` **sí** se versiona, que es lo que hace reproducible el pipeline dentro de un año.

### Comandos

```bash
cd tools
uv sync                              # entorno desde el lockfile
uv run python -m fittracker_data.build_all          # todo
uv run python -m fittracker_data.build_all --only exercises
uv run pytest                        # pruebas del pipeline
uv run ruff check . && uv run mypy src
```

---

## Fuente 1 — Ejercicios (`free-exercise-db`)

**Licencia: Unlicense (dominio público).** Sin obligaciones.

### Descarga

Un solo archivo JSON con ~800 ejercicios desde el repositorio de GitHub, más las rutas relativas de sus imágenes. La forma de cada registro upstream:

```json
{
  "id": "Alternate_Incline_Dumbbell_Curl",
  "name": "Alternate Incline Dumbbell Curl",
  "force": "pull",
  "level": "beginner",
  "mechanic": "isolation",
  "equipment": "dumbbell",
  "primaryMuscles": ["biceps"],
  "secondaryMuscles": ["forearms"],
  "instructions": ["Sit on an incline bench...", "..."],
  "category": "strength",
  "images": ["Alternate_Incline_Dumbbell_Curl/0.jpg", "..."]
}
```

> Verificar las rutas exactas (del JSON y de las imágenes) contra el repositorio al implementar. Se resuelven una vez en `config.py` y no vuelven a tocarse.

### Transformación

| Upstream | Destino | Nota |
|---|---|---|
| `id` | `source_id` | Llave estable del upsert |
| `name` | `name` | Se conserva el original en inglés |
| — | `name_es` | `NULL`; se llena a mano solo para los que uses |
| `primaryMuscles`, `secondaryMuscles`, `instructions` | columnas JSON | Se serializan tal cual |
| `images` | `image_urls` | Rutas relativas convertidas a **URL absoluta** del CDN |
| `force`, `level`, `mechanic`, `equipment`, `category` | columnas homónimas | Valores normalizados a minúsculas |

Las imágenes **no se descargan aquí**. El JSON lleva URLs; la app las trae bajo demanda y las cachea en disco, con un ajuste de "precargar todo por WiFi". Es lo que mantiene el APK en decenas y no en cientos de MB.

### Validaciones que abortan el build

- Que no haya `source_id` duplicados.
- Que todos los ejercicios tengan nombre e instrucciones no vacías.
- Que cada URL de imagen tenga forma válida (no se verifica que responda: son ~1,700 peticiones).
- Que el conteo no caiga más de 10 % respecto al build anterior. Una caída grande significa que el upstream cambió de formato, no que borraron ejercicios.

---

## Fuente 2 — Alimentos (USDA FoodData Central)

**Licencia: dominio público** (obra del gobierno de EE. UU.). La API key gratuita solo se usa aquí, jamás desde la app.

### Qué se descarga y qué no

| Dataset | ¿Se empaqueta? | Por qué |
|---|---|---|
| **Foundation Foods** (~300) | Sí | Los mejor analizados, con perfiles completos |
| **SR Legacy** (~7,800) | Sí | Alimentos genéricos: cortes de carne, granos, verduras. Es lo que sirve para comida casera |
| Survey (FNDDS) | No | Platillos compuestos de la dieta estadounidense; poco aplicable |
| **Branded Foods** (2M+) | **No** | Cientos de MB y orientado al mercado estadounidense. Los productos empacados salen de Open Food Facts al escanear |

Se usa la **descarga masiva en CSV**, no la API: una API key con límite por hora no sirve para traer 8,000 alimentos, y el volcado completo es un ZIP.

### Transformación

Los CSV de USDA vienen normalizados en varias tablas (`food.csv`, `food_nutrient.csv`, `nutrient.csv`, `food_portion.csv`, `measure_unit.csv`). El pipeline los une con pandas y pivota los nutrientes de filas a columnas.

Nutrientes que se extraen (por número de nutriente de USDA; se validan contra `nutrient.csv` en vez de confiar en la constante):

| Nutriente | Número | Columna destino |
|---|---|---|
| Energy (kcal) | 1008 | `kcal_100` |
| Protein | 1003 | `protein_g_100` |
| Carbohydrate, by difference | 1005 | `carbs_g_100` |
| Total lipid (fat) | 1004 | `fat_g_100` |
| Fiber, total dietary | 1079 | `fiber_g_100` |
| Sugars, total | 2000 | `sugar_g_100` |
| Fatty acids, total saturated | 1258 | `sat_fat_g_100` |
| Sodium, Na | 1093 | `sodium_mg_100` |

Los valores de USDA ya vienen por 100 g, que es justo la convención del esquema: no hay conversión, solo pivoteo. Cuando falta la energía en kcal (1008) y solo hay kJ (1062), se convierte dividiendo entre 4.184. Si falta cualquier macro principal, **el alimento se descarta**: un alimento sin proteína registrada contamina tus totales en silencio, y es peor que su ausencia.

Las porciones de `food_portion.csv` se emiten como `food_portion` ("1 cup", "1 medium", con su equivalente en gramos), que es lo que hace usable el registro diario.

### Validación de calidad: la regla 4-4-9

Un control que vale la pena escribir explícitamente:

```
kcal_calculadas = 4 × proteína_g + 4 × carbohidratos_g + 9 × grasa_g
desviación = |kcal_100 − kcal_calculadas| / max(kcal_100, 1)
```

Con desviación > 25 %, el alimento se marca en un reporte. Con > 50 %, se descarta. Atrapa filas corruptas y errores de unidades que de otro modo aparecerían meses después como "¿por qué mis calorías no cuadran?". El alcohol y la fibra desvían legítimamente la fórmula, así que es un filtro con reporte, no un rechazo ciego: el build imprime cuántos descartó y por qué.

---

## Fuente 3 — Open Food Facts (en línea, sin ingesta)

**Licencia: ODbL 1.0** — atribución obligatoria y *share-alike* sobre bases de datos derivadas que se publiquen.

Esta fuente **no tiene pipeline**. Se consulta desde la app al escanear un código de barras, y el resultado se guarda en `food` con `source='off'` como caché local permanente.

Dos consecuencias que derivan directamente de la licencia:

1. **Los datos de Open Food Facts nunca entran al repo.** La caché vive solo en tu dispositivo. Mientras no publiques una base derivada, la cláusula de *share-alike* no se activa.
2. **La app muestra la atribución** en la pantalla de Acerca de, y el README también.

Al normalizar la respuesta hay dos trampas: Open Food Facts a veces reporta macros **por porción** en vez de por 100 g, y a menudo faltan campos. La normalización va en `data/` con pruebas sobre respuestas reales guardadas como fixtures, y si tras normalizar faltan macros principales, la app va al alta manual con lo que sí llegó prellenado.

---

## El manifiesto

`build_all.py` escribe `app/assets/catalog/manifest.json`:

```json
{
  "generated_at": "2026-09-12T18:04:11Z",
  "datasets": {
    "exercises": {
      "version": 3,
      "row_count": 873,
      "sha256": "a3f1…",
      "source": "yuhonas/free-exercise-db",
      "source_ref": "commit 9c1f2ab",
      "license": "Unlicense"
    },
    "foods_usda": {
      "version": 2,
      "row_count": 8104,
      "portion_count": 14992,
      "sha256": "7b0e…",
      "source": "USDA FoodData Central — Foundation + SR Legacy",
      "source_ref": "release 2026-04",
      "license": "Public Domain"
    }
  }
}
```

La app compara cada `version` contra `app_setting.catalog_version_*`. Si es mayor, corre la siembra; si es igual, no hace nada. Ese entero es todo el mecanismo de disparo.

**Regla de determinismo:** el mismo insumo produce byte por byte la misma salida —claves ordenadas, orden de filas estable, sin marcas de tiempo dentro de los datos. Sin eso, cada regeneración produce un diff de 8,000 líneas y nunca vuelves a revisar un cambio de catálogo. Con eso, el diff muestra exactamente los alimentos que cambiaron.

---

## Cómo se actualiza sin perder tus datos

El punto central del documento.

### El mecanismo: upsert por `(source, source_id)`

La siembra no borra ni recrea nada. Inserta o actualiza, fila por fila, dentro de una transacción:

```sql
INSERT INTO food (source, source_id, name, base_unit,
                  kcal_100, protein_g_100, carbs_g_100, fat_g_100,
                  fiber_g_100, sugar_g_100, sat_fat_g_100, sodium_mg_100,
                  created_at, updated_at)
VALUES (:source, :source_id, :name, :base_unit, …, :now, :now)
ON CONFLICT (source, source_id) DO UPDATE SET
    name          = excluded.name,
    base_unit     = excluded.base_unit,
    kcal_100      = excluded.kcal_100,
    protein_g_100 = excluded.protein_g_100,
    carbs_g_100   = excluded.carbs_g_100,
    fat_g_100     = excluded.fat_g_100,
    fiber_g_100   = excluded.fiber_g_100,
    sugar_g_100   = excluded.sugar_g_100,
    sat_fat_g_100 = excluded.sat_fat_g_100,
    sodium_mg_100 = excluded.sodium_mg_100,
    updated_at    = excluded.updated_at
WHERE food.source <> 'user';
```

Lo que protege tus datos no es una salvaguarda añadida, es la forma de la sentencia:

| Qué se protege | Cómo |
|---|---|
| **Tus alimentos propios** | `source='user'` con `source_id=NULL`. En SQLite dos `NULL` son distintos en un índice único, así que nunca entran en conflicto con nada del catálogo. El `WHERE` final es cinturón además de tirantes. |
| **`is_favorite` y `user_notes`** | Sencillamente **no aparecen en el `SET`**. Un alimento marcado como favorito sigue marcado tras la actualización. Mismo mecanismo en `exercise`. |
| **Tu historial de comidas** | `meal_entry` referencia `food.id`, que es interno y estable. El upsert nunca cambia un `id`. Y aunque cambiara la definición del alimento, la **instantánea** de macros del registro ya congeló lo que contaba ese día. |
| **Tus rutinas y sesiones** | Igual: referencian `exercise.id`, que no se mueve. |

### Filas que desaparecen del upstream

**Nunca se borran.** Se marcan con `deleted_at` para que dejen de aparecer en búsquedas, y las referencias históricas siguen resolviendo. Borrar físicamente un alimento que está en una comida de marzo destruiría ese registro; el ahorro de espacio es irrelevante frente a eso.

### El ciclo completo de una actualización

1. `uv run python -m fittracker_data.build_all` en tu máquina.
2. Revisas el diff de `app/assets/catalog/`. Como la salida es determinista, el diff son solo los cambios reales.
3. Commit, push, CI construye el APK.
4. Instalas el APK. Al arrancar, la app compara el `version` del manifiesto contra `app_setting` y corre la siembra si subió.
5. La siembra ocurre en una transacción con una barra de progreso. Si falla a la mitad, hace rollback y la BD queda como estaba.

### La prueba que da confianza

En la Fase 1 y otra vez en la Fase 2, esta prueba es obligatoria:

```
1. Sembrar catálogo versión N
2. Marcar un ejercicio como favorito y escribirle una nota
3. Crear un alimento propio y registrar una comida con él
4. Sembrar catálogo versión N+1 (con un nombre cambiado y una fila nueva)
5. Verificar:
   - el favorito sigue marcado y la nota intacta
   - el alimento propio existe sin cambios
   - la comida registrada conserva sus macros originales
   - el nombre cambiado se actualizó
   - la fila nueva se insertó
   - no hay duplicados
```

Si esa prueba pasa, actualizar el catálogo deja de dar miedo. Si no existe, actualizar el catálogo es una apuesta cada vez.

---

## El camino de salida: exportación para análisis

El complemento del pipeline de entrada. La app exporta (desde la Fase 0) y `tools/analysis/` consume:

```python
import json, pandas as pd
from pathlib import Path

export = json.loads(Path("fittracker-export-2026-09-12.json").read_text(encoding="utf-8"))

meals    = pd.DataFrame(export["meal_entry"])
sets     = pd.DataFrame(export["workout_set"])
sessions = pd.DataFrame(export["workout_session"])

# Calorías por día contra el objetivo vigente
diario = meals.groupby("log_date")[["kcal", "protein_g", "carbs_g", "fat_g"]].sum()

# Volumen por ejercicio y semana (el calentamiento no cuenta)
trabajo = sets[sets.set_type != "warmup"].copy()
trabajo["volumen"] = trabajo.reps * trabajo.weight_kg
```

Que esto sea tan corto es consecuencia directa de dos decisiones del esquema: la instantánea de macros en `meal_entry` (no hay que reconstruir nada) y `set_type` explícito (el filtro de calentamiento es una línea).
