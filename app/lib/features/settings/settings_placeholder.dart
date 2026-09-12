import 'package:flutter/material.dart';

/// Placeholder de la Fase 0. La exportación/importación real de esta
/// misma fase vive en su propia pantalla (ver export_import_page.dart);
/// el resto de Ajustes (objetivos, API key) llega en Fases 2 y 4.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: const Center(child: Text('Objetivos y API key llegan en fases futuras')),
    );
  }
}
