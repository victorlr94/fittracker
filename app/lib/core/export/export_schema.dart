/// Orden seguro para restaurar una tabla a la vez: cada tabla aparece
/// después de todas las que referencia por llave foránea (ver los
/// diagramas de docs/01-modelo-de-datos.md). Para exportar el orden no
/// importa; se reutiliza esta misma lista por simplicidad.
///
/// food_portion      -> food
/// recipe_ingredient -> recipe, food, food_portion
/// recipe_step       -> recipe
/// routine_exercise  -> routine, exercise
/// workout_session   -> routine
/// workout_set       -> workout_session, exercise
/// meal_entry        -> food, recipe, food_portion
const List<String> kExportTableOrder = [
  'app_setting',
  'exercise',
  'food',
  'routine',
  'recipe',
  'food_portion',
  'recipe_ingredient',
  'recipe_step',
  'routine_exercise',
  'workout_session',
  'workout_set',
  'meal_entry',
  'nutrition_target',
];
