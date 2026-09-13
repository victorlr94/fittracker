import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';

/// Acceso a `exercise`: catálogo, búsqueda por FTS5, favoritos y el
/// upsert versionado que usa la siembra del catálogo
/// (docs/03-ingesta-de-datos.md).
class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Future<List<Exercise>> listAll({bool favoritesOnly = false}) {
    final query = _db.select(_db.exercises)
      ..where((e) => e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.asc(e.name)]);
    if (favoritesOnly) {
      query.where((e) => e.isFavorite.equals(true));
    }
    return query.get();
  }

  Future<Exercise?> getById(int id) {
    return (_db.select(_db.exercises)..where((e) => e.id.equals(id)))
        .getSingleOrNull();
  }

  /// Búsqueda con FTS5 (sin acentos) más filtros opcionales. El orden por
  /// relevancia de la búsqueda se conserva; sin texto, se ordena por nombre.
  Future<List<Exercise>> search({
    String query = '',
    String? equipment,
    String? level,
    String? muscle,
  }) async {
    List<int>? ftsIds;
    if (query.trim().isNotEmpty) {
      ftsIds = await _matchingIds(query);
      if (ftsIds.isEmpty) return const [];
    }

    final q = _db.select(_db.exercises)..where((e) => e.deletedAt.isNull());
    if (ftsIds != null) {
      final ids = ftsIds;
      q.where((e) => e.id.isIn(ids));
    }
    if (equipment != null) {
      q.where((e) => e.equipment.equals(equipment));
    }
    if (level != null) {
      q.where((e) => e.level.equals(level));
    }
    if (ftsIds == null) {
      q.orderBy([(e) => OrderingTerm.asc(e.name)]);
    }

    var rows = await q.get();

    if (muscle != null) {
      rows = rows.where((e) => _hasMuscle(e, muscle)).toList();
    }

    if (ftsIds != null) {
      final rank = {for (var i = 0; i < ftsIds.length; i++) ftsIds[i]: i};
      rows.sort((a, b) => (rank[a.id] ?? 0).compareTo(rank[b.id] ?? 0));
    }

    return rows;
  }

  bool _hasMuscle(Exercise exercise, String muscle) {
    final primary = (jsonDecode(exercise.primaryMuscles) as List).cast<String>();
    final secondary =
        (jsonDecode(exercise.secondaryMuscles) as List).cast<String>();
    return primary.contains(muscle) || secondary.contains(muscle);
  }

  /// Ids que hacen match en `exercise_fts`, en orden de relevancia (`rank`
  /// de FTS5: entre más negativo, mejor match — así lo ordena SQLite).
  Future<List<int>> _matchingIds(String query) async {
    final ftsQuery = _sanitizeFtsQuery(query);
    if (ftsQuery.isEmpty) return const [];
    final rows = await _db
        .customSelect(
          'SELECT rowid AS id FROM exercise_fts '
          'WHERE exercise_fts MATCH ? ORDER BY rank',
          variables: [Variable(ftsQuery)],
        )
        .get();
    return rows.map((r) => r.read<int>('id')).toList();
  }

  /// Envuelve cada palabra entre comillas con `*` de prefijo: hace que
  /// cualquier texto del usuario sea una consulta FTS5 válida (sin que
  /// caracteres como `-` o `"` rompan la sintaxis de MATCH).
  String _sanitizeFtsQuery(String input) {
    final terms = input
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '""')}"*');
    return terms.join(' ');
  }

  Future<void> setFavorite(int id, bool value) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id)))
        .write(ExercisesCompanion(isFavorite: Value(value)));
  }

  Future<void> setUserNotes(int id, String? notes) {
    return (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(userNotes: Value(notes)),
    );
  }

  Future<List<String>> distinctEquipment() async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT equipment FROM exercise '
          "WHERE equipment IS NOT NULL AND deleted_at IS NULL "
          'ORDER BY equipment',
        )
        .get();
    return rows.map((r) => r.read<String>('equipment')).toList();
  }

  Future<List<String>> distinctMuscles() async {
    final rows = await listAll();
    final muscles = <String>{};
    for (final row in rows) {
      muscles.addAll((jsonDecode(row.primaryMuscles) as List).cast<String>());
      muscles.addAll((jsonDecode(row.secondaryMuscles) as List).cast<String>());
    }
    final sorted = muscles.toList()..sort();
    return sorted;
  }

  /// Upsert por `(source, sourceId)` — el mecanismo de la siembra
  /// versionada del catálogo. Nunca toca `isFavorite` ni `userNotes`
  /// (invariante #4 de CLAUDE.md): esas columnas simplemente no se
  /// mencionan en la parte de actualización, así que Drift no las incluye
  /// en el `UPDATE ... SET`.
  Future<void> upsertFromCatalog(ExercisesCompanion row) {
    return _db.into(_db.exercises).insert(
      row,
      onConflict: DoUpdate.withExcluded(
        (old, excluded) => ExercisesCompanion.custom(
          name: excluded.name,
          nameEs: excluded.nameEs,
          force: excluded.force,
          level: excluded.level,
          mechanic: excluded.mechanic,
          equipment: excluded.equipment,
          category: excluded.category,
          primaryMuscles: excluded.primaryMuscles,
          secondaryMuscles: excluded.secondaryMuscles,
          instructions: excluded.instructions,
          imageUrls: excluded.imageUrls,
          updatedAt: excluded.updatedAt,
        ),
        target: [_db.exercises.source, _db.exercises.sourceId],
      ),
    );
  }
}
