import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/export/export_service.dart';
import '../../data/local/catalog_seeder.dart';

/// Ajustes. En la Fase 0 solo vive aquí la exportación/importación
/// (docs/00-decisiones.md ADR-007, docs/02-roadmap.md Fase 0). Objetivos
/// nutricionales y la API key del modelo de visión llegan en Fases 2 y 4.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Respaldo de datos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Un solo archivo .zip con todos tus datos: un export.json '
            'completo (para restaurar) y un .csv por tabla (para analizar '
            'en Python). Sin cuenta ni nube: si pierdes este archivo, '
            'pierdes tu historial.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _exportNow(context, ref),
            icon: const Icon(Icons.upload_outlined),
            label: const Text('Exportar ahora'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _importFrom(context, ref),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Restaurar desde un archivo'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Catálogo de ejercicios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Si los nombres, el equipo o los músculos se ven en inglés '
            'después de una actualización, es porque la app todavía no '
            'resembró el catálogo. Este botón lo fuerza sin esperar a la '
            'siguiente versión.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          _CatalogVersionRow(db: ref.watch(appDatabaseProvider)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _forceReseedCatalog(context, ref),
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar catálogo ahora'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Objetivos nutricionales y la clave de la API de Claude '
            '(para el módulo de foto) se configuran aquí en fases '
            'futuras.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<void> _forceReseedCatalog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(appDatabaseProvider);
      await CatalogSeeder(db).forceReseedExercises();
      messenger.showSnackBar(
        const SnackBar(content: Text('Catálogo actualizado.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el catálogo: $e')),
      );
    }
  }

  Future<void> _exportNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(appDatabaseProvider);
      final result = await ExportService(db).exportAll();

      final savedUri = await FilePicker.saveFile(
        fileName: result.suggestedFileName,
        bytes: result.zipBytes,
        mimeType: 'application/zip',
        dialogTitle: 'Guardar respaldo de FitTracker',
      );

      if (savedUri == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Exportación cancelada.')),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Respaldo guardado: ${result.totalRows} filas en '
            '${result.rowCounts.length} tablas.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    }
  }

  Future<void> _importFrom(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'Esto REEMPLAZA todos los datos actuales de la app por los del '
          'archivo elegido. Esta acción no se puede deshacer.\n\n'
          '¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Elige un respaldo de FitTracker',
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );
      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();
      final isZip = (file.extension ?? '').toLowerCase() == 'zip';

      final db = ref.read(appDatabaseProvider);
      final result =
          await ExportService(db).importFrom(bytes, isZip: isZip);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restaurado: ${result.totalRows} filas en '
            '${result.rowCounts.length} tablas.',
          ),
        ),
      );
    } on InvalidBackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo restaurar: $e')),
      );
    }
  }
}

class _CatalogVersionRow extends StatelessWidget {
  const _CatalogVersionRow({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: CatalogSeeder(db).installedExercisesVersion(),
      builder: (context, snapshot) {
        final version = snapshot.data;
        return Text(
          version == null
              ? 'Versión instalada: (todavía no se siembra)'
              : 'Versión instalada: $version',
          style: const TextStyle(color: Colors.black54),
        );
      },
    );
  }
}
