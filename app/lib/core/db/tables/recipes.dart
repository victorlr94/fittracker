import 'package:drift/drift.dart';

import 'food.dart';

/// Receta: ingredientes + pasos. Las macros por porción NO se almacenan
/// aquí; se derivan en `domain/services` a partir de `RecipeIngredients`.
/// Ver docs/01-modelo-de-datos.md § recipe, recipe_ingredient, recipe_step.
class Recipes extends Table {
  @override
  String get tableName => 'recipe';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().named('name')();
  TextColumn get description => text().named('description').nullable()();
  RealColumn get servings => real().named('servings')();
  TextColumn get servingLabel =>
      text().named('serving_label').nullable()();
  IntColumn get prepMinutes => integer().named('prep_minutes').nullable()();

  /// Ruta local en el dispositivo.
  TextColumn get imagePath => text().named('image_path').nullable()();
  TextColumn get source =>
      text().named('source').withDefault(const Constant('user'))();

  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();

  @override
  List<String> get customConstraints => [
        'CHECK (servings > 0)',
      ];
}

class RecipeIngredients extends Table {
  @override
  String get tableName => 'recipe_ingredient';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get recipeId => integer()
      .named('recipe_id')
      .references(Recipes, #id, onDelete: KeyAction.cascade)();

  IntColumn get foodId =>
      integer().named('food_id').references(Foods, #id)();

  /// Cantidad canónica: todo cálculo de macros parte de aquí.
  RealColumn get grams => real().named('grams')();

  /// Cómo lo capturaste tú ("2 tazas"), aparte de la verdad en gramos.
  IntColumn get displayPortionId => integer()
      .named('display_portion_id')
      .nullable()
      .references(FoodPortions, #id)();
  RealColumn get displayQuantity =>
      real().named('display_quantity').nullable()();

  IntColumn get position => integer().named('position')();

  @override
  List<String> get customConstraints => [
        'CHECK (grams > 0)',
      ];
}

class RecipeSteps extends Table {
  @override
  String get tableName => 'recipe_step';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get recipeId => integer()
      .named('recipe_id')
      .references(Recipes, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer().named('position')();
  TextColumn get text_ => text().named('text')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {recipeId, position},
      ];
}
