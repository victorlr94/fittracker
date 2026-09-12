import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Nombre de archivo de la base de datos en el dispositivo.
const String kDatabaseFileName = 'fittracker.sqlite';

/// Abre la conexión nativa de la base de datos, en un isolate en segundo
/// plano (recomendado por Drift: libera al hilo principal del trabajo de
/// E/S de SQLite).
///
/// `sqlite3` no incluye ya un empaquetado de librerías nativas propio
/// (`sqlite3_flutter_libs` está descontinuado desde su versión 0.6.0: la
/// versión 3.x de `sqlite3` las trae integradas). Lo único que sigue
/// haciendo falta a mano en Android es indicarle a sqlite3 un directorio
/// temporal válido, porque `/tmp` no existe ahí. Ese ajuste se hace dentro
/// del isolate en segundo plano (vía `isolateSetup`), no en el principal,
/// porque `sqlite3.tempDirectory` es un valor por isolate.
Future<QueryExecutor> openConnection() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, kDatabaseFileName));

  String? androidTempDir;
  if (Platform.isAndroid) {
    androidTempDir = (await getTemporaryDirectory()).path;
  }

  return NativeDatabase.createInBackground(
    file,
    isolateSetup: () async {
      if (androidTempDir != null) {
        sqlite3.tempDirectory = androidTempDir;
      }
    },
  );
}

/// Conexión en memoria, para pruebas. Nunca toca el disco.
QueryExecutor openTestConnection() => NativeDatabase.memory();
