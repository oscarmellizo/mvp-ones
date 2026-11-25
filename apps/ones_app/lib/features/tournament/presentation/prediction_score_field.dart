import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PredictionScoreField extends StatelessWidget {
  const PredictionScoreField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.scoreCorrect,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool? scoreCorrect;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final markColor = switch (scoreCorrect) {
      true => Colors.green.shade700,
      false => colors.error,
      null => null,
    };
    final borderColor = markColor ?? colors.outlineVariant;

    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            readOnly: !enabled,
            showCursor: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, color: markColor),
            decoration: InputDecoration(
              counterText: '',
              hintText: '–',
              filled: true,
              fillColor: markColor?.withValues(alpha: 0.08) ??
                  colors.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: markColor ?? colors.primary,
                  width: 1.6,
                ),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 9,
                horizontal: 6,
              ),
            ),
            maxLength: 2,
            onChanged: onChanged,
          ),
          if (scoreCorrect != null) ...[
            const SizedBox(height: 3),
            Tooltip(
              message: scoreCorrect!
                  ? 'Este marcador coincide con el real'
                  : 'Este marcador no coincide con el real',
              child: Icon(
                scoreCorrect!
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 13,
                color: markColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
