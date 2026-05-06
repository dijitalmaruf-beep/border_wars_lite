import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/territory.dart';

class AttackDialog extends StatelessWidget {
  const AttackDialog({
    required this.source,
    required this.target,
    required this.winChance,
    super.key,
  });

  final Territory source;
  final Territory target;
  final double winChance;

  @override
  Widget build(BuildContext context) {
    final percent = (winChance * 100).round();
    return AlertDialog(
      title: const Text('Confirm Attack'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${source.name} -> ${target.name}'),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: winChance.clamp(0.0, 1.0).toDouble(),
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 8),
          Text(
            '$percent% win chance',
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.gps_fixed),
          label: const Text('Attack'),
        ),
      ],
    );
  }
}
