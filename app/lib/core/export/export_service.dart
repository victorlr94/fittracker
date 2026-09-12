import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart' show Csv;

import '../db/app_database.dart';
import 'export_schema.dart';

/// Versión del formato de intercambio (distinta de `schemaVersion` de la
/// BD). Cambia solo si cambia la FORMA del .zip/.json en sí, no cada vez
/// que se agrega una tabla al esquema.
const int kExportFormatVersion = 1;

/// Se lanza cuando el archivo a importar no es un respaldo válido de esta
/// app, o su formato no es compatible con esta versión.
class InvalidBackupException implements Exception {
  InvalidBackupException(this.message);
  final String message;

  @override
  String toString() => 'InvalidBackupException: $message';
}

class ExportResult {
  ExportResult({
    required this.zipBytes,
    required this.rowCounts,
    required this.suggestedFileName,
  });

  final Uint8List zipBytes;
  final Map<String, int> rowCounts;
  final String suggestedFileName;

  int get totalRows => rowCounts.values.fold(0, (a, b) => a + b);
}

class ImportResult {
  ImportResult(this.rowCounts);
  final Map<String, int> rowCounts;

  int get totalRows => rowCounts.values.fold(0, (a, b) => a + b);
}

/// Exporta e importa TODOS los datos de la app en un solo .zip:
/// `export.json` (fidelidad total — es lo que se reimporta) más un `.csv`
/// por tabla (para abrir con pandas). Ver docs/03-ingesta-de-datos.md
/// § "El camino de salida" y docs/00-decisiones.md ADR-007.
///
/// Las claves del JSON son los nombres de columna EXACTOS de
/// docs/01-modelo-de-datos.md (snake_case: `source_id`, `kcal_100`...),
/// no los nombres camelCase que Drift usa del lado Dart. Por eso esta
/// clase lee con SQL crudo (`SELECT * FROM <tabla>`) en vez de usar los
/// `toJson()` generados: así el formato en disco es estable aunque el
/// código Dart interno cambie de forma, y `pandas.DataFrame(...)` no
/// necesita traducir nombres de columna.
///
/// Importar es una RESTAURACIÓN, no una fusión: reemplaza todo el
/// contenido actual de la base. Para un respaldo personal (sin
/// colaboración entre dispositivos) es la semántica correcta y la más
/// simple de razonar.
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  Future<ExportResult> exportAll() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in kExportTableOrder) {
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      tables[table] = rows.map((r) => r.data).toList();
    }

    final payload = <String, Object?>{
      'format_version': kExportFormatVersion,
      'schema_version': _db.schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };

    final archive = Archive()
      ..addFile(ArchiveFile.bytes(
        'export.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
      ));

    for (final entry in tables.entries) {
      archive.addFile(
        ArchiveFile.bytes('${entry.key}.csv', utf8.encode(_toCsv(entry.value))),
      );
    }

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final rowCounts = {
      for (final entry in tables.entries) entry.key: entry.value.length,
    };

    return ExportResult(
      zipBytes: zipBytes,
      rowCounts: rowCounts,
      suggestedFileName: 'fittracker-export-${_timestamp(DateTime.now())}.zip',
    );
  }

  static String _toCsv(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return '';
    final header = rows.first.keys.toList(growable: false);
    final data = <List<Object?>>[
      header,
      for (final row in rows) [for (final key in header) row[key]],
    ];
    return Csv().encode(data);
  }

  static String _timestamp(DateTime t) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${p2(t.month)}${p2(t.day)}-${p2(t.hour)}${p2(t.minute)}${p2(t.second)}';
  }

  /// [fileBytes] es el contenido crudo de un `.zip` producido por
  /// [exportAll], o de un `export.json` suelto (por si se extrajo del zip
  /// a mano). [isZip] decide cómo interpretarlo.
  Future<ImportResult> importFrom(Uint8List fileBytes, {required bool isZip}) async {
    final Map<String, Object?> payload = isZip
        ? _extractJsonFromZip(fileBytes)
        : jsonDecode(utf8.decode(fileBytes)) as Map<String, Object?>;

    final formatVersion = payload['format_version'];
    if (formatVersion != kExportFormatVersion) {
      throw InvalidBackupException(
        'Versión de formato de respaldo no soportada: $formatVersion '
        '(esperada: $kExportFormatVersion).',
      );
    }

    final rawTables = payload['tables'];
    if (rawTables is! Map) {
      throw InvalidBackupException('El respaldo no tiene la clave "tables".');
    }

    final rowCounts = <String, int>{};

    // PRAGMA foreign_keys no se puede cambiar dentro de una transacción
    // (limitación de SQLite, documentada en la propia API de Drift). Se
    // desactiva ANTES de abrir la transacción y se reactiva al final,
    // todo bajo `exclusively()` para que ninguna otra operación se cuele
    // en medio con las llaves foráneas apagadas.
    await _db.exclusively(() async {
      await _db.customStatement('PRAGMA foreign_keys = OFF');
      try {
        await _db.transaction(() async {
          for (final table in kExportTableOrder.reversed) {
            await _db.customStatement('DELETE FROM $table');
          }

          for (final table in kExportTableOrder) {
            final rows = (rawTables[table] as List<dynamic>? ?? const [])
                .cast<Map<String, dynamic>>();
            for (final row in rows) {
              await _insertRawRow(table, row);
            }
            rowCounts[table] = rows.length;
          }

          final problems =
              await _db.customSelect('PRAGMA foreign_key_check').get();
          if (problems.isNotEmpty) {
            throw InvalidBackupException(
              'El respaldo viola ${problems.length} referencia(s) entre '
              'tablas; no se aplicó ningún cambio.',
            );
          }
        });
      } finally {
        await _db.customStatement('PRAGMA foreign_keys = ON');
      }
    });

    return ImportResult(rowCounts);
  }

  Map<String, Object?> _extractJsonFromZip(Uint8List zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? jsonFile;
    for (final f in archive.files) {
      if (f.name == 'export.json') {
        jsonFile = f;
        break;
      }
    }
    if (jsonFile == null) {
      throw InvalidBackupException(
        'El .zip no contiene export.json; no es un respaldo de FitTracker.',
      );
    }
    return jsonDecode(utf8.decode(jsonFile.content)) as Map<String, Object?>;
  }

  Future<void> _insertRawRow(String table, Map<String, dynamic> row) async {
    final columns = row.keys.toList(growable: false);
    final placeholders = List.filled(columns.length, '?').join(', ');
    final sql =
        'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)';
    await _db.customStatement(sql, [for (final c in columns) row[c]]);
  }
}
