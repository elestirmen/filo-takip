import 'package:flutter/material.dart';

import '../core/strings.dart';

/// Henüz yazılmamış ekranların gövdesi. Aşama tamamlandıkça kaldırılır.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            Strings.screenComingSoon,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
