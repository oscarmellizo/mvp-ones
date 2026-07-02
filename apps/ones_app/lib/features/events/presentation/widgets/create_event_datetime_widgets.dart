import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import 'create_event_form_widgets.dart';

class CreateEventDateTimeCard extends StatelessWidget {
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String? errorText;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickEndTime;

  const CreateEventDateTimeCard({
    super.key,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.errorText,
    required this.onPickStartDate,
    required this.onPickStartTime,
    required this.onPickEndDate,
    required this.onPickEndTime,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: OnesColors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          CreateEventDateTimeRow(
            icon: Icons.calendar_month,
            title: t.translate('create_event.starts'),
            dateValue: _formatDate(startDate),
            timeValue: _formatTime(context, startTime),
            onPickDate: onPickStartDate,
            onPickTime: onPickStartTime,
          ),
          const SizedBox(height: 14),
          CreateEventDateTimeRow(
            icon: Icons.event_busy,
            title: t.translate('create_event.ends'),
            dateValue: _formatDate(endDate),
            timeValue: _formatTime(context, endTime),
            onPickDate: onPickEndDate,
            onPickTime: onPickEndTime,
          ),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: OnesColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd/mm/aaaa';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  String _formatTime(BuildContext context, TimeOfDay? time) {
    if (time == null) {
      return context.read<TranslationsService>().translate(
            'create_event.placeholder_time',
          );
    }
    return time.format(context);
  }
}
