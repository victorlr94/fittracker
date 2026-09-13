import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../data/local/repository_providers.dart';

/// Ficha de ejercicio: instrucciones, músculos, imágenes bajo demanda con
/// caché (docs/00-decisiones.md, "APK ligero") y notas propias.
///
/// Con [selectionMode] en true (al elegir un ejercicio para una rutina o
/// una sesión) se agrega una barra inferior para confirmar o regresar a
/// la lista sin elegir — así se puede ver la imagen antes de decidir,
/// en vez de agregar el ejercicio a ciegas con solo el nombre en inglés.
class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({
    required this.exerciseId,
    this.selectionMode = false,
    super.key,
  });

  final int exerciseId;
  final bool selectionMode;

  @override
  ConsumerState<ExerciseDetailPage> createState() =>
      _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  Exercise? _exercise;
  late final TextEditingController _notesController;
  Timer? _notesDebounce;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final exercise = await ref
        .read(exerciseRepositoryProvider)
        .getById(widget.exerciseId);
    if (!mounted) return;
    setState(() {
      _exercise = exercise;
      _notesController.text = exercise?.userNotes ?? '';
    });
  }

  Future<void> _toggleFavorite() async {
    final exercise = _exercise;
    if (exercise == null) return;
    await ref
        .read(exerciseRepositoryProvider)
        .setFavorite(exercise.id, !exercise.isFavorite);
    await _load();
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(exerciseRepositoryProvider)
          .setUserNotes(widget.exerciseId, value.isEmpty ? null : value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;
    if (exercise == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final images = (jsonDecode(exercise.imageUrls) as List).cast<String>();
    final primaryMuscles =
        (jsonDecode(exercise.primaryMuscles) as List).cast<String>();
    final secondaryMuscles =
        (jsonDecode(exercise.secondaryMuscles) as List).cast<String>();
    final instructions =
        (jsonDecode(exercise.instructions) as List).cast<String>();

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.nameEs ?? exercise.name),
        actions: [
          IconButton(
            icon: Icon(
              exercise.isFavorite ? Icons.star : Icons.star_border,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (images.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(
                children: [
                  for (final url in images)
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin imagen para este ejercicio',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (exercise.equipment != null)
                Chip(label: Text(exercise.equipment!)),
              if (exercise.level != null) Chip(label: Text(exercise.level!)),
              if (exercise.mechanic != null)
                Chip(label: Text(exercise.mechanic!)),
            ],
          ),
          const SizedBox(height: 16),
          if (primaryMuscles.isNotEmpty) ...[
            Text('Músculos primarios', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final m in primaryMuscles)
                  Chip(
                    label: Text(m),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (secondaryMuscles.isNotEmpty) ...[
            Text('Músculos secundarios', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [for (final m in secondaryMuscles) Chip(label: Text(m))],
            ),
            const SizedBox(height: 12),
          ],
          const Divider(),
          const SizedBox(height: 8),
          Text('Instrucciones', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(instructions[i])),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: 8),
          Text('Tus notas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'p. ej. "ojo con el hombro izquierdo"',
              border: OutlineInputBorder(),
            ),
            onChanged: _onNotesChanged,
          ),
          if (widget.selectionMode)
            // Espacio para que la barra inferior no tape las notas.
            const SizedBox(height: 72),
        ],
      ),
      bottomNavigationBar: widget.selectionMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check),
                  label: const Text('Agregar este ejercicio'),
                ),
              ),
            )
          : null,
    );
  }
}
