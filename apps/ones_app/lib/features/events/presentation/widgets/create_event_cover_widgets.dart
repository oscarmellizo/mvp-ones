import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import 'create_event_form_widgets.dart';

class CreateEventCoverPicker extends StatelessWidget {
  final String? imageUrl;
  final bool loading;
  final bool accepted;
  final String? errorText;
  final VoidCallback? onGenerate;
  final bool showGenerateHelper;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;

  const CreateEventCoverPicker({
    super.key,
    required this.imageUrl,
    required this.loading,
    required this.accepted,
    required this.errorText,
    required this.onGenerate,
    required this.showGenerateHelper,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              color: OnesColors.yellowPale.withOpacity(0.55),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: imageUrl == null
                        ? const SizedBox.shrink()
                        : Image.network(imageUrl!, fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          OnesColors.black
                              .withOpacity(imageUrl == null ? 0 : 0.10),
                          OnesColors.black
                              .withOpacity(imageUrl == null ? 0 : 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                if (imageUrl == null && !loading)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: const CreateEventDashedBorderPainter(
                        color: OnesColors.purpleBright,
                        radius: 18,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: OnesColors.yellowPale,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.image,
                              color: OnesColors.purpleMid,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Event Cover',
                            style: TextStyle(
                              color: OnesColors.purpleMid,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (loading)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (errorText != null && errorText!.trim().isNotEmpty) ...[
          Text(
            errorText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OnesColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (showGenerateHelper) ...[
          const Text(
            'Complete name and objective to generate a cover.',
            style: TextStyle(
              color: OnesColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: OnesColors.purpleMid,
                  foregroundColor: OnesColors.white,
                  disabledBackgroundColor: OnesColors.purpleMid.withOpacity(0.5),
                  disabledForegroundColor: OnesColors.white.withOpacity(0.85),
                ),
                onPressed: (loading || onGenerate == null) ? null : onGenerate,
                child: loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        accepted ? 'Regenerate' : 'Generate with AI',
                      ),
              ),
            ),
            if (imageUrl != null && !accepted) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnesColors.purpleMid,
                    side: const BorderSide(
                      color: OnesColors.purpleMid,
                      width: 1.6,
                    ),
                  ),
                  onPressed: onAccept,
                  child: const Text('Use'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OnesColors.purpleMid,
                    side: const BorderSide(
                      color: OnesColors.purpleMid,
                      width: 1.6,
                    ),
                  ),
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
