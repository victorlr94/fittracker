import 'package:drift/drift.dart';

import 'food.dart';
import 'recipes.dart';

/// Una comida registrada: exactamente uno de `foodId` / `recipeId`, con
/// una INSTANTÁNEA de las macros calculadas al momento de registrar.
///
/// La instantánea es la decisión más importante de esta tabla (invariante
/// #3 de CLAUDE.md): editar el alimento o la receta origen después NUNCA
/// cambia una comida ya registrada. Ver docs/01-modelo-de-datos.md § meal_entry.
class MealEntries extends Table {
  @override
  String get tableName => 'meal_entry';

  IntColumn get id => integer().autoIncrement()();

  /// 'YYYY-MM-DD', fecha LOCAL del día en que se registró.
  TextColumn get logDate => text().named('log_date')();

  /// 'desayuno' | 'comida' | 'cena' | 'snack'.
  TextColumn get mealSlot => text().named('meal_slot')();
  IntColumn get position =>
      integer().named('position').withDefault(const Constant(0))();

  // Exactamente uno de los dos (ver customConstraints).
  IntColumn get foodId =>
      integer().named('food_id').nullable().references(Foods, #id)();
  IntColumn get recipeId =>
      integer().named('recipe_id').nullable().references(Recipes, #id)();

  RealColumn get quantityG => real().named('quantity_g').nullable()();
  RealColumn get servings => real().named('servings').nullable()();
  IntColumn get displayPortionId => integer()
      .named('display_portion_id')
      .nullable()
      .references(FoodPortions, #id)();
  RealColumn get displayQuantity =>
      real().named('display_quantity').nullable()();

  // INSTANTÁNEA: macros congeladas al momento de registrar. Nunca se
  // recalculan a partir de food/recipe después de escritas.
  RealColumn get kcal => real().named('kcal')();
  RealColumn get proteinG => real().named('protein_g')();
  RealColumn get carbsG => real().named('carbs_g')();
  RealColumn get fatG => real().named('fat_g')();
  RealColumn get fiberG => real().named('fiber_g').nullable()();
  RealColumn get sodiumMg => real().named('sodium_mg').nullable()();

  /// Instante UTC, epoch ms.
  IntColumn get loggedAt => integer().named('logged_at')();

  /// Desfase local (minutos) al momento de registrar. Junto con `logDate`
  /// evita que un viaje entre zonas horarias reinterprete el pasado.
  IntColumn get tzOffsetMinutes =>
      integer().named('tz_offset_minutes')();

  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  List<String> get customConstraints => [
        "CHECK (meal_slot IN ('desayuno', 'comida', 'cena', 'snack'))",
        'CHECK ((food_id IS NOT NULL) <> (recipe_id IS NOT NULL))',
        'CHECK (food_id IS NULL OR (quantity_g IS NOT NULL AND quantity_g > 0))',
        'CHECK (recipe_id IS NULL OR (servings IS NOT NULL AND servings > 0))',
      ];
}

/// Objetivo nutricional vigente desde `effectiveFrom`, con historial: nunca
/// se edita una fila, se inserta una nueva. Ver docs/01-modelo-de-datos.md.
class NutritionTargets extends Table {
  @override
  String get tableName => 'nutrition_target';

  IntColumn get id => integer().autoIncrement()();

  /// 'YYYY-MM-DD'.
  TextColumn get effectiveFrom =>
      text().named('effective_from').unique()();

  RealColumn get kcal => real().named('kcal')();
  RealColumn get proteinG => real().named('protein_g')();
  RealColumn get carbsG => real().named('carbs_g')();
  RealColumn get fatG => real().named('fat_g')();
  RealColumn get fiberG => real().named('fiber_g').nullable()();
  TextColumn get note => text().named('note').nullable()();

  IntColumn get createdAt => integer().named('created_at')();
}
