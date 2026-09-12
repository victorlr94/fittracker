import 'package:drift/drift.dart';

/// Catálogo de ejercicios. `primaryMuscles`, `secondaryMuscles`,
/// `instructions` e `imageUrls` son listas cortas guardadas como JSON en
/// TEXT: normalizarlas en tablas aparte sería ceremonia sin beneficio,
/// porque nunca se consultan por separado (docs/01-modelo-de-datos.md).
///
/// `imageUrls` guarda URLs remotas, no archivos: las imágenes se
/// descargan y cachean bajo demanda (docs/00-decisiones.md, "APK ligero").
class Exercises extends Table {
  @override
  String get tableName => 'exercise';

  IntColumn get id => integer().autoIncrement()();

  /// 'free-exercise-db' | 'user' | 'wger'.
  TextColumn get source => text().named('source')();
  TextColumn get sourceId => text().named('source_id').nullable()();

  TextColumn get name => text().named('name')();
  TextColumn get nameEs => text().named('name_es').nullable()();

  /// push | pull | static.
  TextColumn get force => text().named('force').nullable()();

  /// beginner | intermediate | expert.
  TextColumn get level => text().named('level').nullable()();

  /// compound | isolation.
  TextColumn get mechanic => text().named('mechanic').nullable()();
  TextColumn get equipment => text().named('equipment').nullable()();
  TextColumn get category => text().named('category').nullable()();

  /// JSON array de strings.
  TextColumn get primaryMuscles => text()
      .named('primary_muscles')
      .withDefault(const Constant('[]'))();
  TextColumn get secondaryMuscles => text()
      .named('secondary_muscles')
      .withDefault(const Constant('[]'))();

  /// JSON array de pasos (strings), en orden.
  TextColumn get instructions =>
      text().named('instructions').withDefault(const Constant('[]'))();

  /// JSON array de URLs.
  TextColumn get imageUrls =>
      text().named('image_urls').withDefault(const Constant('[]'))();

  BoolColumn get isFavorite =>
      boolean().named('is_favorite').withDefault(const Constant(false))();

  /// Sobrevive a las actualizaciones del catálogo: el upsert nunca la toca.
  TextColumn get userNotes => text().named('user_notes').nullable()();

  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();
  IntColumn get deletedAt => integer().named('deleted_at').nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {source, sourceId},
      ];

  @override
  List<String> get customConstraints => [
        "CHECK (source IN ('free-exercise-db', 'user', 'wger'))",
      ];
}
