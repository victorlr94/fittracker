import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../data/local/repository_providers.dart';
import 'exercise_detail_page.dart';

/// Catálogo de ejercicios: búsqueda por FTS5, filtros por equipo/músculo,
/// favoritos. Ver docs/02-roadmap.md, Fase 1.
class ExerciseCatalogPage extends ConsumerStatefulWidget {
  const ExerciseCatalogPage({super.key, this.pickerMode = false});

  /// Si es true, tocar un ejercicio hace `pop` devolviendo su id (para
  /// "agregar ejercicio" desde una rutina) en vez de abrir la ficha.
  final bool pickerMode;

  @override
  ConsumerState<ExerciseCatalogPage> createState() =>
      _ExerciseCatalogPageState();
}

class _ExerciseCatalogPageState extends ConsumerState<ExerciseCatalogPage> {
  Timer? _debounce;
  String _query = '';
  String? _equipment;
  String? _muscle;
  bool _favoritesOnly = false;

  List<Exercise> _results = const [];
  List<String> _equipmentOptions = const [];
  List<String> _muscleOptions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final repo = ref.read(exerciseRepositoryProvider);
    final equipment = await repo.distinctEquipment();
    final muscles = await repo.distinctMuscles();
    if (!mounted) return;
    setState(() {
      _equipmentOptions = equipment;
      _muscleOptions = muscles;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(exerciseRepositoryProvider);
    final results = _favoritesOnly
        ? await repo.listAll(favoritesOnly: true)
        : await repo.search(
            query: _query,
            equipment: _equipment,
            muscle: _muscle,
          );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _query = value;
      _load();
    });
  }

  Future<void> _toggleFavorite(Exercise exercise) async {
    await ref
        .read(exerciseRepositoryProvider)
        .setFavorite(exercise.id, !exercise.isFavorite);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickerMode ? 'Elegir ejercicio' : 'Ejercicios'),
        actions: [
          IconButton(
            tooltip: 'Solo favoritos',
            icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
            onPressed: () {
              setState(() => _favoritesOnly = !_favoritesOnly);
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar ejercicio…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown(
                    label: 'Equipo',
                    value: _equipment,
                    options: _equipmentOptions,
                    onChanged: (v) {
                      setState(() => _equipment = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterDropdown(
                    label: 'Músculo',
                    value: _muscle,
                    options: _muscleOptions,
                    onChanged: (v) {
                      setState(() => _muscle = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final exercise = _results[i];
                      return ListTile(
                        title: Text(exercise.nameEs ?? exercise.name),
                        subtitle: Text(
                          [
                            if (exercise.equipment != null) exercise.equipment!,
                            if (exercise.level != null) exercise.level!,
                          ].join(' · '),
                        ),
                        trailing: widget.pickerMode
                            ? const Icon(Icons.chevron_right)
                            : IconButton(
                                icon: Icon(
                                  exercise.isFavorite
                                      ? Icons.star
                                      : Icons.star_border,
                                ),
                                onPressed: () => _toggleFavorite(exercise),
                              ),
                        onTap: () async {
                          if (widget.pickerMode) {
                            // Primero una previsualización (imagen,
                            // músculos, instrucciones): recién ahí se
                            // confirma o se regresa a seguir buscando,
                            // en vez de agregarlo a ciegas al tocarlo.
                            final confirmed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDetailPage(
                                      exerciseId: exercise.id,
                                      selectionMode: true,
                                    ),
                                  ),
                                );
                            if (confirmed == true && context.mounted) {
                              Navigator.of(context).pop(exercise.id);
                            }
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExerciseDetailPage(exerciseId: exercise.id),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: onChanged,
    );
  }
}
