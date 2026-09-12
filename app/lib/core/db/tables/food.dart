import 'package:drift/drift.dart';

/// Alimento genérico, de código de barras o propio, en una sola tabla.
///
/// Ver docs/01-modelo-de-datos.md § Nutrición y docs/00-decisiones.md ADR-003.
/// `source` distingue el origen; `(source, sourceId)` es la llave contra la
/// que hace upsert la ingesta de catálogo (docs/03-ingesta-de-datos.md).
class Foods extends Table {
  @override
  String get tableName => 'food';

  IntColumn get id => integer().autoIncrement()();

  /// 'usda' | 'off' | 'user'.
  TextColumn get source => text().named('source')();

  /// fdcId de USDA, código de barras de Open Food Facts, o NULL si es tuyo.
  /// SQLite trata NULL como distinto de NULL en un índice UNIQUE, así que
  /// muchas filas `source='user'` con `sourceId=NULL` nunca chocan entre sí.
  TextColumn get sourceId => text().named('source_id').nullable()();

  TextColumn get name => text().named('name')();
  TextColumn get nameEs => text().named('name_es').nullable()();
  TextColumn get brand => text().named('brand').nullable()();
  TextColumn get barcode => text().named('barcode').nullable()();

  /// 'g' | 'ml'.
  TextColumn get baseUnit =>
      text().named('base_unit').withDefault(const Constant('g'))();

  // Macros SIEMPRE por 100 g (o 100 ml si baseUnit = 'ml').
  RealColumn get kcal100 => real().named('kcal_100')();
  RealColumn get proteinG100 => real().named('protein_g_100')();
  RealColumn get carbsG100 => real().named('carbs_g_100')();
  RealColumn get fatG100 => real().named('fat_g_100')();
  RealColumn get fiberG100 => real().named('fiber_g_100').nullable()();
  RealColumn get sugarG100 => real().named('sugar_g_100').nullable()();
  RealColumn get satFatG100 => real().named('sat_fat_g_100').nullable()();
  RealColumn get sodiumMg100 => real().named('sodium_mg_100').nullable()();

  BoolColumn get isFavorite =>
      boolean().named('is_favorite').withDefault(const Constant(false))();

  /// Sobrevive a las actualizaciones del catálogo: el upsert nunca la toca.
  TextColumn get userNotes => text().named('user_notes').nullable()();

  /// Unix epoch en milisegundos, UTC.
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {source, sourceId},
      ];

  @override
  List<String> get customConstraints => [
        "CHECK (source IN ('usda', 'off', 'user'))",
        "CHECK (base_unit IN ('g', 'ml'))",
        'CHECK (kcal_100 >= 0)',
        'CHECK (protein_g_100 >= 0)',
        'CHECK (carbs_g_100 >= 0)',
        'CHECK (fat_g_100 >= 0)',
      ];
}

/// Porción nombrada de un alimento ("1 taza", "1 pieza mediana").
///
/// Es lo que hace usable el registro diario: nadie sabe cuántos gramos pesa
/// una tortilla, pero todo el mundo sabe que se comió tres.
class FoodPortions extends Table {
  @override
  String get tableName => 'food_portion';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get foodId => integer()
      .named('food_id')
      .references(Foods, #id, onDelete: KeyAction.cascade)();

  TextColumn get label => text().named('label')();
  RealColumn get grams => real().named('grams')();
  BoolColumn get isDefault =>
      boolean().named('is_default').withDefault(const Constant(false))();

  /// 'usda' | 'off' | 'user'.
  TextColumn get source => text().named('source')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {foodId, label},
      ];

  @override
  List<String> get customConstraints => [
        'CHECK (grams > 0)',
      ];
}
