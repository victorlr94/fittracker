import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/rest_timer_notifications.dart';
import '../../../data/local/repository_providers.dart';
import '../../../domain/entities/set_type.dart';
import '../catalog/exercise_catalog_page.dart';
import 'log_set_sheet.dart';
import 'session_starter.dart';

const _defaultRestDuration = Duration(seconds: 90);

/// Sesión en vivo: iniciar (con o sin rutina), registrar series una por
/// una con prellenado y cronómetro de descanso, y terminar
/// (docs/02-roadmap.md, Fase 1). El estado de la sesión vive en la BD
/// desde la primera serie, no en memoria: si la app se cierra a medias,
/// no se pierde nada.
class LiveSessionPage extends ConsumerStatefulWidget {
  const LiveSessionPage({super.key});

  @override
  ConsumerState<LiveSessionPage> createState() => _LiveSessionPageState();
}

class _LiveSessionPageState extends ConsumerState<LiveSessionPage> {
  WorkoutSession? _session;
  int? _selectedRoutineIdForStart;
  String? _activeRoutineName;

  List<Exercise> _sessionExercises = const [];
  int? _selectedExerciseId;
  List<WorkoutSet> _currentSets = const [];

  StreamSubscription<WorkoutSession?>? _sessionSub;
  StreamSubscription<List<WorkoutSet>>? _setsSub;

  Timer? _restTicker;
  int _restSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _sessionSub = ref
        .read(workoutRepositoryProvider)
        .watchActiveSession()
        .listen(_onSessionChanged);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _setsSub?.cancel();
    _restTicker?.cancel();
    super.dispose();
  }

  Future<void> _onSessionChanged(WorkoutSession? session) async {
    setState(() => _session = session);
    _setsSub?.cancel();
    _setsSub = null;

    if (session == null) {
      setState(() {
        _sessionExercises = const [];
        _selectedExerciseId = null;
        _currentSets = const [];
        _activeRoutineName = null;
      });
      return;
    }

    await _loadSessionExercises(session);
    _setsSub = ref
        .read(workoutRepositoryProvider)
        .watchSetsForSession(session.id)
        .listen(_onSetsChanged);
  }

  Future<void> _loadSessionExercises(WorkoutSession session) async {
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final exerciseRepo = ref.read(exerciseRepositoryProvider);

    String? routineName;
    final ids = <int>[];
    if (session.routineId != null) {
      routineName = (await workoutRepo.getRoutineById(session.routineId!))
          ?.name;

      final routineExercises = await workoutRepo.exercisesForRoutine(
        session.routineId!,
      );
      ids.addAll(routineExercises.map((re) => re.exerciseId));
    }
    final loggedSoFar = await workoutRepo.setsForSession(session.id);
    for (final s in loggedSoFar) {
      if (!ids.contains(s.exerciseId)) ids.add(s.exerciseId);
    }

    final exercises = <Exercise>[];
    for (final id in ids) {
      final exercise = await exerciseRepo.getById(id);
      if (exercise != null) exercises.add(exercise);
    }

    if (!mounted) return;
    setState(() {
      _sessionExercises = exercises;
      _activeRoutineName = routineName;
      _selectedExerciseId ??= exercises.isNotEmpty ? exercises.first.id : null;
    });
  }

  void _onSetsChanged(List<WorkoutSet> sets) {
    setState(() => _currentSets = sets);
  }

  List<WorkoutSet> get _setsForSelectedExercise => _currentSets
      .where((s) => s.exerciseId == _selectedExerciseId)
      .toList();

  Future<void> _startSession() {
    return startSessionWithConfirmation(
      context,
      ref,
      routineId: _selectedRoutineIdForStart,
    );
  }

  Future<void> _endSession() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terminar sesión'),
        content: const Text('¿Terminar el entrenamiento de hoy?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir entrenando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _restTicker?.cancel();
    await RestTimerNotifications.cancel();
    await ref.read(workoutRepositoryProvider).endSession(session.id);
  }

  Future<void> _addAdHocExercise() async {
    final exerciseId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => const ExerciseCatalogPage(pickerMode: true),
      ),
    );
    if (exerciseId == null) return;
    if (_sessionExercises.any((e) => e.id == exerciseId)) {
      setState(() => _selectedExerciseId = exerciseId);
      return;
    }
    final exercise = await ref
        .read(exerciseRepositoryProvider)
        .getById(exerciseId);
    if (exercise == null || !mounted) return;
    setState(() {
      _sessionExercises = [..._sessionExercises, exercise];
      _selectedExerciseId = exerciseId;
    });
  }

  Future<void> _logSet() async {
    final session = _session;
    final exerciseId = _selectedExerciseId;
    if (session == null || exerciseId == null) return;

    final exercise = _sessionExercises.firstWhere((e) => e.id == exerciseId);
    final currentIndex = _setsForSelectedExercise.length;

    final lastSets = await ref
        .read(workoutRepositoryProvider)
        .lastSetsForExercise(exerciseId, excludingSessionId: session.id);
    final prefill = lastSets.isEmpty
        ? null
        : lastSets[currentIndex.clamp(0, lastSets.length - 1)];

    if (!mounted) return;
    final result = await LogSetSheet.show(
      context,
      exerciseName: exercise.nameEs ?? exercise.name,
      prefillReps: prefill?.reps,
      prefillWeightKg: prefill?.weightKg,
    );
    if (result == null) return;

    await ref
        .read(workoutRepositoryProvider)
        .logSet(
          sessionId: session.id,
          exerciseId: exerciseId,
          position: currentIndex,
          setType: result.setType,
          reps: result.reps,
          weightKg: result.weightKg,
          rpe: result.rpe,
        );

    _startRestTimer();
  }

  Future<void> _deleteSet(int setId) {
    return ref.read(workoutRepositoryProvider).deleteSet(setId);
  }

  void _startRestTimer([Duration duration = _defaultRestDuration]) {
    _restTicker?.cancel();
    setState(() => _restSecondsLeft = duration.inSeconds);
    RestTimerNotifications.scheduleRestOver(duration);
    _restTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _restSecondsLeft = 0);
      } else {
        setState(() => _restSecondsLeft -= 1);
      }
    });
  }

  void _skipRest() {
    _restTicker?.cancel();
    RestTimerNotifications.cancel();
    setState(() => _restSecondsLeft = 0);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return _buildStartScreen();
    return _buildActiveSession(session);
  }

  Widget _buildStartScreen() {
    // routinesProvider es reactivo: crear o borrar una rutina en la
    // pestaña Rutinas se refleja aquí solo, sin depender de que esta
    // pestaña se reconstruya al cambiar de tab.
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sesión')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No hay una sesión en curso.'),
              const SizedBox(height: 16),
              routinesAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, stackTrace) =>
                    Text('No se pudieron cargar las rutinas: $error'),
                data: (routines) => DropdownButtonFormField<int?>(
                  initialValue: _selectedRoutineIdForStart,
                  decoration: const InputDecoration(
                    labelText: 'Rutina (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sesión libre'),
                    ),
                    for (final r in routines)
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedRoutineIdForStart = v),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startSession,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSession(WorkoutSession session) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activeRoutineName == null
              ? 'Sesión libre en curso'
              : 'Sesión: $_activeRoutineName',
        ),
        actions: [
          TextButton(
            onPressed: _endSession,
            child: const Text('Terminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_restSecondsLeft > 0) _buildRestBanner(),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final exercise in _sessionExercises)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(exercise.nameEs ?? exercise.name),
                      selected: _selectedExerciseId == exercise.id,
                      onSelected: (_) =>
                          setState(() => _selectedExerciseId = exercise.id),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Ejercicio'),
                    onPressed: _addAdHocExercise,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedExerciseId == null
                ? const Center(child: Text('Agrega un ejercicio para empezar'))
                : _buildSetsList(),
          ),
        ],
      ),
      floatingActionButton: _selectedExerciseId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _logSet,
              icon: const Icon(Icons.add),
              label: const Text('Registrar serie'),
            ),
    );
  }

  Widget _buildRestBanner() {
    final minutes = _restSecondsLeft ~/ 60;
    final seconds = _restSecondsLeft % 60;
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined),
          const SizedBox(width: 8),
          Text(
            'Descanso: $minutes:${seconds.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          TextButton(onPressed: _skipRest, child: const Text('Saltar')),
        ],
      ),
    );
  }

  Widget _buildSetsList() {
    final sets = _setsForSelectedExercise;
    if (sets.isEmpty) {
      return const Center(child: Text('Sin series todavía en este ejercicio'));
    }
    return ListView.builder(
      itemCount: sets.length,
      itemBuilder: (context, i) {
        final set = sets[i];
        final type = SetType.fromDb(set.setType);
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(
            [
              if (set.reps != null) '${set.reps} reps',
              if (set.weightKg != null) '${set.weightKg} kg',
              if (set.durationSeconds != null) '${set.durationSeconds} s',
            ].join(' · '),
          ),
          subtitle: type == SetType.normal ? null : Text(_setTypeLabel(type)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteSet(set.id),
          ),
        );
      },
    );
  }
}

String _setTypeLabel(SetType type) => switch (type) {
  SetType.normal => 'Normal',
  SetType.warmup => 'Calentamiento',
  SetType.drop => 'Dropset',
  SetType.failure => 'Al fallo',
};
