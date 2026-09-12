# Prompt para Claude Code — Planificación de app de seguimiento de comidas y entrenamientos

Quiero que actúes como arquitecto de software y líder técnico. Tu tarea en esta sesión es **planificar** (no implementar todavía) una app Android que voy a usar yo mismo para dar seguimiento a mis comidas y entrenamientos. Al final de la sesión quiero un conjunto de documentos en el repo que sirvan de base para que en sesiones posteriores tú mismo implementes fase por fase.

## Contexto sobre mí

- Ingeniero con experiencia sólida en Python, SQL y análisis de datos / ML. Poca experiencia en desarrollo móvil.
- Estoy fortaleciendo mi perfil en AI Engineering (RAG, agentes, pipelines con LLMs). Este proyecto también es pieza de portafolio, así que la calidad de ingeniería importa: estructura clara, pruebas, documentación, versionado.
- Quiero aprender haciendo: explícame las decisiones de arquitectura de forma práctica, sin sermones.

## Qué quiero construir

**v1: APK para uso personal**, instalada en mi celular Android, sin usuarios ni backend propio. Debe funcionar offline para todo lo básico; solo el módulo de foto necesita internet.

Se irá mejorando por versiones conforme detecte necesidades de uso. Existe la posibilidad remota de volverla comercial en el futuro: **no** diseñes para eso ahora (nada de auth, multi-tenant, backend en la nube, monetización), pero evita decisiones que lo hagan imposible después (por ejemplo: esquema de datos exportable, capa de acceso a datos aislada, licencias de datasets anotadas).

### Módulos funcionales

1. **Entrenamientos**
   - Catálogo de ejercicios con: músculos primarios/secundarios, equipo, nivel, instrucciones paso a paso para ejecutarlos correctamente, imagen o GIF.
   - Fuente inicial: dataset open source `yuhonas/free-exercise-db` (dominio público, JSON, ~800 ejercicios). Evaluar también wger (open source, REST API, Docker) como alternativa de backend/datos. ExerciseDB (11k ejercicios) es de pago para producción; descártalo o déjalo documentado como opción futura.
   - Registro de sesiones: rutina, ejercicio, series, reps, peso, RPE opcional, notas, duración.
   - Historial y progresión por ejercicio (gráficas simples de volumen / 1RM estimado).
   - Rutinas armadas por mí (plantillas reutilizables).

2. **Comidas**
   - Búsqueda de alimentos con macros por porción. Fuentes: USDA FoodData Central (gratis) y Open Food Facts (gratis, incluye productos con código de barras vendidos en México).
   - Registro de comidas por día/momento (desayuno, comida, cena, snacks) con porciones editables.
   - Totales diarios de calorías y macros contra un objetivo configurable.
   - Alimentos y platillos propios (comida mexicana casera no suele estar bien cubierta en esas bases; necesito poder crearlos a mano).
   - Escaneo de código de barras (Open Food Facts).

3. **Recetas fit**
   - Recetas con ingredientes, pasos, imagen y macros por porción calculados a partir de los ingredientes.
   - Poder registrar una porción de receta como comida.
   - Fuente inicial: recetas cargadas por mí; opcionalmente Spoonacular/Edamam como fuente externa (evalúa límites del plan gratuito).

4. **Estimación de calorías por foto (fase posterior, no MVP)**
   - Flujo: foto del plato → modelo de visión multimodal (API de Claude) → JSON estructurado con lista de alimentos, porción estimada en gramos y nivel de confianza → cruce con base nutricional → **el usuario confirma o corrige** ítems y porciones antes de guardar.
   - Diséñalo explícitamente como sugerencia editable, no como verdad. Una foto no da volumen ni densidad; el error esperable es alto.
   - Guardar la estimación del modelo y la corrección del usuario por separado, para poder medir después qué tan bien estima el modelo (esto es material de evaluación para portafolio).
   - La API key no debe ir hardcodeada en el APK: guardarla en almacenamiento seguro del dispositivo, ingresada desde una pantalla de configuración.

## Restricciones y preferencias técnicas

- Android es obligatorio. Recomiéndame el stack entre **Flutter**, **Kotlin + Jetpack Compose** y **React Native / Expo**, con una tabla comparativa según: curva de aprendizaje para alguien que viene de Python, velocidad para llegar a un APK funcional, soporte offline/SQLite, manejo de cámara y código de barras, facilidad de que tú lo mantengas en sesiones futuras, y opción de iOS en el futuro. Da una recomendación concreta y justifícala.
- Base de datos local (SQLite o equivalente) con migraciones versionadas desde el día uno.
- Datos importables/exportables (JSON o CSV) para no quedar atrapado en la app y para poder analizarlos después en Python.
- Sin backend propio en v1. Si concluyes que wger u otro backend local en Docker aporta más que construir el módulo de entrenos desde cero, argumenta el trade-off.
- Pruebas unitarias sobre lógica de negocio (cálculo de macros, progresión, parseo de respuestas del modelo). No busques cobertura total, busca cubrir lo que rompe silenciosamente.
- Documentar en el repo las licencias y condiciones de uso de cada dataset/API que usemos.

## Lo que quiero que entregues en esta sesión

Crea en el repo los siguientes archivos:

1. `docs/00-decisiones.md` — decisiones de arquitectura en formato ADR corto (contexto, opciones, decisión, consecuencias). Como mínimo: stack móvil, base de datos local, fuentes de datos por módulo, estrategia para el módulo de foto.
2. `docs/01-modelo-de-datos.md` — esquema de tablas con campos, tipos, claves y relaciones. Incluye cómo se representa un alimento genérico, uno propio, una receta y una comida registrada, y cómo se guarda una sesión de entrenamiento.
3. `docs/02-roadmap.md` — fases con alcance cerrado. Propuesta inicial que puedes ajustar:
   - Fase 0: esqueleto del proyecto, CI mínima, build de APK, base de datos y migraciones.
   - Fase 1: entrenamientos (catálogo + registro + historial).
   - Fase 2: comidas (búsqueda, registro, totales, alimentos propios, código de barras).
   - Fase 3: recetas.
   - Fase 4: estimación por foto.
   Para cada fase: criterio de "terminado", riesgos y qué se prueba.
4. `docs/03-ingesta-de-datos.md` — cómo se descargan, transforman y cargan los datasets externos (scripts en Python están bien), incluyendo cómo se actualizan sin perder mis datos.
5. `docs/04-modulo-foto.md` — diseño del pipeline de visión: prompt al modelo, esquema JSON esperado, manejo de errores y timeouts, costo estimado por foto, y cómo evaluaremos su precisión con mis propias correcciones.
6. `CLAUDE.md` — instrucciones para ti mismo en sesiones futuras: estructura del repo, comandos de build/test, convenciones, y regla de trabajar una fase a la vez.

## Cómo quiero que trabajes

- Antes de escribir los documentos, hazme **máximo 5 preguntas** cuyas respuestas cambien realmente el diseño. Si algo se puede resolver con un supuesto razonable, avanza y deja el supuesto anotado en el documento correspondiente.
- Sé crítico: si alguna parte de lo que pido está mal planteada, es innecesaria para v1 o tiene un riesgo que no estoy viendo, dilo y propón una alternativa.
- No implementes código de la app en esta sesión, salvo el esqueleto mínimo si es necesario para validar que el stack elegido compila y genera un APK.
- Escribe los documentos en español.
