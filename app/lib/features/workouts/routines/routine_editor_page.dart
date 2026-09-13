import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../data/local/repository_providers.dart';
import '../catalog/exercise_catalog_page.dart';
import '../session/session_starter.dart';
import '../workouts_tab_index.dart';

class _RoutineItem {
  const _RoutineItem(this.routineExercise, this.exercise);
  final RoutineExercise routineExercise;
  final Exercise exercise;
}

/// Editar los ejercicios de una rutina: agregar (desde el catálogo,
/// docs/02-roadmap.md Fase 1), quitar y reordenar arrastrando.
class RoutineEditorPage extends ConsumerStatefulWidget {
  const RoutineEditorPage({required this.routineId, super.key});

  final int routineId;

  @override
  ConsumerState<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends ConsumerState<RoutineEditorPage> {
  List<_RoutineItem> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final exerciseRepo = ref.read(exerciseRepositoryProvider);

    final routineExercises = await workoutRepo.exercisesForRoutine(
      widget.routineId,
    );
    final items = <_RoutineItem>[];
    for (final re in routineExercises) {
      final exercise = await exerciseRepo.getById(re.exerciseId);
      if (exercise != null) items.add(_RoutineItem(re, exercise));
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addExercise() async {
    final exerciseId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => const ExerciseCatalogPage(pickerMode: true),
      ),
    );
    if (exerciseId == null) return;

    await ref
        .read(workoutRepositoryProvider)
        .addExerciseToRoutine(routineId: widget.routineId, exerciseId: exerciseId);
    await _load();
  }

  Future<void> _removeExercise(_RoutineItem item) async {
    await ref
        .read(workoutRepositoryProvider)
        .removeExerciseFromRoutine(item.routineExercise.id);
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final items = List<_RoutineItem>.from(_items);
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    setState(() => _items = items); // respuesta inmediata en la UI
    await ref
        .read(workoutRepositoryProvider)
        .reorderRoutineExercises(items.map((i) => i.routineExercise.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar rutina'),
        actions: [
          IconButton(
            tooltip: 'Iniciar sesión con esta rutina',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => startSessionWithConfirmation(
              context,
              ref,
              routineId: widget.routineId,
              switchToTabIndex: kSessionTabIndex,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin ejercicios todavía. Agrega el primero con el botón '
                  'de abajo.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              itemCount: _items.length,
              onReorderItem: _reorder,
              itemBuilder: (context, i) {
                final item = _items[i];
                return ListTile(
                  key: ValueKey(item.routineExercise.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(item.exercise.nameEs ?? item.exercise.name),
                  subtitle: item.routineExercise.targetSets == null
                      ? null
                      : Text(
                          '${item.routineExercise.targetSets} series'
                          '${item.routineExercise.targetRepsMin != null ? ' × ${item.routineExercise.targetRepsMin}-${item.routineExercise.targetRepsMax ?? item.routineExercise.targetRepsMin} reps' : ''}',
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeExercise(item),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
    );
  }
}
