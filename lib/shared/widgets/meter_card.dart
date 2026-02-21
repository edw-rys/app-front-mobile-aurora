import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/meter_model.dart';
import '../../data/models/reading_model.dart';

/// Reusable meter card widget matching the mockup design
class MeterCard extends StatelessWidget {
  final MeterModel meter;
  final ReadingModel? reading;
  final VoidCallback? onTap;
  final ValueChanged<String>? onReadingQuickSave;

  const MeterCard({
    super.key,
    required this.meter,
    this.reading,
    this.onTap,
    this.onReadingQuickSave,
  });

  bool get _hasReading => reading?.currentReading != null;

  @override
  Widget build(BuildContext context) {
    final isSynced = reading?.synced == true;
    final hasError = reading != null && (!reading!.isValid || reading!.syncError != null);

    Color borderColor = AppColors.border;
    double borderWidth = 0.5;

    if (hasError) {
      borderColor = AppColors.error;
      borderWidth = 1.5;
    } else if (isSynced) {
      borderColor = AppColors.success;
      borderWidth = 1.5;
    } else if (_hasReading) {
      borderColor = AppColors.primary.withValues(alpha: 0.3);
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client name + status indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                    meter.clientName,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_hasReading) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isSynced ? AppColors.success : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // Address
            Text(
              meter.address,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Bottom row: meter number + previous reading
            Row(
              children: [
                // Meter number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meter.number ?? 'S/N',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                // n_abonado
                Text(
                  meter.nAbonado,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                // Previous reading
                if (meter.reading.previousReading != null)
                  Text(
                    'Ant: ${meter.reading.previousReading}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                // Current reading if read
                if (_hasReading) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.readBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${reading!.currentReading}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.readText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
