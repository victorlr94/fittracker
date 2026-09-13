import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../data/local/repository_providers.dart';
import '../../../domain/entities/logged_set.dart';
import '../../../domain/entities/set_type.dart';
import '../../../domain/services/volume_calculator.dart';
import '../catalog/exercise_catalog_page.dart';
import 'exercise_progression_page.dart';

/// Historial de sesiones y acceso a la gráfica de progresión de un
/// ejercicio (docs/02-roadmap.md, Fase 1).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  List<WorkoutSession> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await ref
        .read(workoutRepositoryProvider)
        .recentSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _openProgression() async {
    final exerciseId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => const ExerciseCatalogPage(pickerMode: true),
      ),
    );
    if (exerciseId == null || !mounted) return;

    final exercise = await ref
        .read(exerciseRepositoryProvider)
        .getById(exerciseId);
    if (exercise == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseProgressionPage(
          exerciseId: exerciseId,
          exerciseName: exercise.nameEs ?? exercise.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: _openProgression,
                    icon: const Icon(Icons.show_chart),
                    label: const Text('Ver progresión de un ejercicio'),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _sessions.isEmpty
                      ? const Center(
                          child: Text('Todavía no has registrado sesiones'),
                        )
                      : ListView.builder(
                          itemCount: _sessions.length,
                          itemBuilder: (context, i) =>
                              _SessionTile(session: _sessions[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(session.sessionDate),
      subtitle: session.endedAt == null
          ? const Text('En curso')
          : session.bodyweightKg != null
          ? Text('Peso corporal: ${session.bodyweightKg} kg')
          : null,
      children: [
        FutureBuilder(
          future: ref.read(workoutRepositoryProvider).setsForSession(session.id),
          builder: (context, snapshot) {
            final sets = snapshot.data;
            if (sets == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (sets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin series registradas'),
              );
            }

            final byExercise = <int, List<WorkoutSet>>{};
            for (final set in sets) {
              byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
            }

            return FutureBuilder<Map<int, String>>(
              future: _exerciseNames(ref, byExercise.keys),
              builder: (context, namesSnapshot) {
                final names = namesSnapshot.data ?? const {};
                return Column(
                  children: [
                    for (final entry in byExercise.entries)
                      ListTile(
                        dense: true,
                        title: Text(names[entry.key] ?? 'Ejercicio'),
                        subtitle: Text(
                          '${entry.value.length} serie(s) · '
                          'volumen ${calculateVolume(entry.value.map((s) => s.toLoggedSet())).round()}',
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<Map<int, String>> _exerciseNames(
    WidgetRef ref,
    Iterable<int> ids,
  ) async {
    final repo = ref.read(exerciseRepositoryProvider);
    final result = <int, String>{};
    for (final id in ids) {
      final exercise = await repo.getById(id);
      if (exercise != null) result[id] = exercise.nameEs ?? exercise.name;
    }
    return result;
  }
}

extension on WorkoutSet {
  LoggedSet toLoggedSet() => LoggedSet(
        setType: SetType.fromDb(setType),
        reps: reps,
        weightKg: weightKg,
      );
}
