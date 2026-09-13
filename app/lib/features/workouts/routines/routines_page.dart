import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../data/local/repository_providers.dart';
import 'routine_editor_page.dart';

/// Lista de rutinas: plantillas reutilizables (docs/01-modelo-de-datos.md
/// § routine). Crear/editar/reordenar ejercicios vive en
/// [RoutineEditorPage].
///
/// Usa [routinesProvider] (reactivo) en vez de una lista cacheada en
/// estado local: así el selector de rutina de la pestaña Sesión se entera
/// de inmediato cuando se crea o borra una aquí, sin depender de que esa
/// pestaña se reconstruya.
class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  Future<void> _createRoutine(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'Nueva rutina');
    if (name == null || name.trim().isEmpty) return;

    final id = await ref
        .read(workoutRepositoryProvider)
        .createRoutine(name: name.trim());
    ref.invalidate(routinesProvider);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutineEditorPage(routineId: id)),
    );
  }

  Future<void> _deleteRoutine(
    BuildContext context,
    WidgetRef ref,
    Routine routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar rutina'),
        content: Text(
          '¿Borrar "${routine.name}"? Tu historial de sesiones no se toca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(workoutRepositoryProvider).deleteRoutine(routine.id);
    ref.invalidate(routinesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas')),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudieron cargar las rutinas: $error')),
        data: (routines) => routines.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no tienes rutinas. Crea una con el botón de '
                    'abajo, o inicia una sesión libre desde la pestaña '
                    'Sesión.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                itemCount: routines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final routine = routines[i];
                  return ListTile(
                    title: Text(routine.name),
                    subtitle: routine.description == null
                        ? null
                        : Text(routine.description!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteRoutine(context, ref, routine),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            RoutineEditorPage(routineId: routine.id),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createRoutine(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<String?> _promptForName(
  BuildContext context, {
  required String title,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre'),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
