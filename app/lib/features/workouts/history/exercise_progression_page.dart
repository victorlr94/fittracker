import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/repository_providers.dart';
import '../../../data/local/workout_repository.dart';

enum _Metric { volume, oneRepMax }

/// Gráficas de volumen y 1RM estimado por sesión para un ejercicio
/// (docs/02-roadmap.md, Fase 1). Ambas son una referencia de tendencia,
/// no una medición exacta (docs/04-modulo-foto.md tiene el mismo
/// principio para las fotos: mostrar la incertidumbre, no esconderla).
class ExerciseProgressionPage extends ConsumerStatefulWidget {
  const ExerciseProgressionPage({
    required this.exerciseId,
    required this.exerciseName,
    super.key,
  });

  final int exerciseId;
  final String exerciseName;

  @override
  ConsumerState<ExerciseProgressionPage> createState() =>
      _ExerciseProgressionPageState();
}

class _ExerciseProgressionPageState
    extends ConsumerState<ExerciseProgressionPage> {
  List<ExerciseSessionSummary> _summaries = const [];
  bool _loading = true;
  _Metric _metric = _Metric.volume;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summaries = await ref
        .read(workoutRepositoryProvider)
        .progressionForExercise(widget.exerciseId);
    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
          ? const Center(
              child: Text('Todavía no hay sesiones registradas de este ejercicio'),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_Metric>(
                    segments: const [
                      ButtonSegment(
                        value: _Metric.volume,
                        label: Text('Volumen'),
                      ),
                      ButtonSegment(
                        value: _Metric.oneRepMax,
                        label: Text('1RM estimado'),
                      ),
                    ],
                    selected: {_metric},
                    onSelectionChanged: (s) => setState(() => _metric = s.first),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildChart()),
                ],
              ),
            ),
    );
  }

  Widget _buildChart() {
    final points = <FlSpot>[];
    for (var i = 0; i < _summaries.length; i++) {
      final summary = _summaries[i];
      final value = _metric == _Metric.volume
          ? summary.volume
          : summary.bestEstimatedOneRepMax;
      if (value != null) points.add(FlSpot(i.toDouble(), value));
    }

    if (points.isEmpty) {
      return const Center(
        child: Text('Sin series con reps y peso para graficar 1RM'),
      );
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: false,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= _summaries.length) return const SizedBox();
                final date = _summaries[i].sessionDate;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(date.substring(5), style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 48),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}
