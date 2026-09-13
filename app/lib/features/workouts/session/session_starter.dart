import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/repository_providers.dart';

String todayLocalDate() {
  final now = DateTime.now();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${p2(now.month)}-${p2(now.day)}';
}

/// Un solo camino para iniciar una sesión, usado tanto desde la pestaña
/// Sesión (selector) como desde el botón de reproducir de una rutina
/// (docs/02-roadmap.md, Fase 1) — para que no haya dos flujos que puedan
/// divergir o fallar de formas distintas.
///
/// Si ya hay una sesión activa, pregunta explícitamente en vez de fallar
/// en silencio: es el caso más fácil de dejar "atorado" sin darse cuenta
/// (p. ej. una sesión libre que se te olvidó terminar).
Future<void> startSessionWithConfirmation(
  BuildContext context,
  WidgetRef ref, {
  int? routineId,
  int? switchToTabIndex,
}) async {
  final repo = ref.read(workoutRepositoryProvider);

  final active = await repo.getActiveSession();
  if (active != null) {
    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ya hay una sesión en curso'),
        content: const Text(
          'Tienes una sesión de entrenamiento sin terminar. Para iniciar '
          'esta primero hay que terminar esa — tus series ya registradas '
          'no se pierden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terminarla e iniciar esta'),
          ),
        ],
      ),
    );
    if (replace != true) return;
    await repo.endSession(active.id);
  }

  try {
    await repo.startSession(
      routineId: routineId,
      sessionDate: todayLocalDate(),
      tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('No se pudo iniciar la sesión: $e')));
    return;
  }

  if (!context.mounted || switchToTabIndex == null) return;
  // Se llamó desde otra pestaña (p. ej. Rutinas): salta a Sesión para ver
  // la sesión recién iniciada de inmediato, en vez de dejarla "iniciada
  // en segundo plano" sin confirmación visible.
  DefaultTabController.maybeOf(context)?.animateTo(switchToTabIndex);
}
