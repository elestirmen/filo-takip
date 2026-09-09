import 'package:flutter/material.dart';

/// Uygulamanın tek tema tanımı. Renkler tek bir tohum renkten üretilir.
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF1565C0);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}
