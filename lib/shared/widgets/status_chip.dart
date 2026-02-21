import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Status chip for meter reading status
class StatusChip extends StatelessWidget {
  final StatusType type;
  final String? label;

  const StatusChip({
    super.key,
    required this.type,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? config.defaultLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: config.text,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  _ChipConfig _getConfig() {
    switch (type) {
      case StatusType.pending:
        return _ChipConfig(
          bg: AppColors.pendingBg,
          text: AppColors.pendingText,
          defaultLabel: 'Pendiente',
        );
      case StatusType.read:
        return _ChipConfig(
          bg: AppColors.readBg,
          text: AppColors.readText,
          defaultLabel: 'Leído',
        );
      case StatusType.error:
        return _ChipConfig(
          bg: AppColors.errorBg,
          text: AppColors.errorText,
          defaultLabel: 'Error',
        );
      case StatusType.synced:
        return _ChipConfig(
          bg: AppColors.readBg,
          text: AppColors.readText,
          defaultLabel: 'Sincronizado',
        );
    }
  }
}

enum StatusType { pending, read, error, synced }

class _ChipConfig {
  final Color bg;
  final Color text;
  final String defaultLabel;
  _ChipConfig({required this.bg, required this.text, required this.defaultLabel});
}
