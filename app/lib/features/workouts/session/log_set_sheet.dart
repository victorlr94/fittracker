import 'package:flutter/material.dart';

import '../../../domain/entities/set_type.dart';

class LogSetResult {
  const LogSetResult({
    required this.setType,
    this.reps,
    this.weightKg,
    this.rpe,
  });

  final SetType setType;
  final int? reps;
  final double? weightKg;
  final double? rpe;
}

/// Formulario de una serie: reps, peso, tipo y RPE opcional. Se abre
/// prellenado con lo que hiciste la última vez en este ejercicio
/// (docs/02-roadmap.md, Fase 1).
class LogSetSheet extends StatefulWidget {
  const LogSetSheet({
    required this.exerciseName,
    this.prefillReps,
    this.prefillWeightKg,
    super.key,
  });

  final String exerciseName;
  final int? prefillReps;
  final double? prefillWeightKg;

  static Future<LogSetResult?> show(
    BuildContext context, {
    required String exerciseName,
    int? prefillReps,
    double? prefillWeightKg,
  }) {
    return showModalBottomSheet<LogSetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogSetSheet(
        exerciseName: exerciseName,
        prefillReps: prefillReps,
        prefillWeightKg: prefillWeightKg,
      ),
    );
  }

  @override
  State<LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends State<LogSetSheet> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _rpeController;
  SetType _setType = SetType.normal;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(
      text: widget.prefillReps?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: widget.prefillWeightKg?.toString() ?? '',
    );
    _rpeController = TextEditingController();
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _rpeController.dispose();
    super.dispose();
  }

  void _submit() {
    final reps = int.tryParse(_repsController.text);
    final weight = double.tryParse(_weightController.text);
    final rpe = double.tryParse(_rpeController.text);
    Navigator.of(context).pop(
      LogSetResult(setType: _setType, reps: reps, weightKg: weight, rpe: rpe),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.exerciseName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Repeticiones',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rpeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'RPE (opcional, 1-10)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final type in SetType.values)
                ChoiceChip(
                  label: Text(_setTypeLabel(type)),
                  selected: _setType == type,
                  onSelected: (_) => setState(() => _setType = type),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Guardar serie'),
            ),
          ),
        ],
      ),
    );
  }
}

String _setTypeLabel(SetType type) => switch (type) {
  SetType.normal => 'Normal',
  SetType.warmup => 'Calentamiento',
  SetType.drop => 'Dropset',
  SetType.failure => 'Al fallo',
};
