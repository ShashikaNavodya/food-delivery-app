import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/app_entry_gate.dart';

class SavorApp extends StatelessWidget {
  const SavorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Savor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppEntryGate(),
    );
  }
}
