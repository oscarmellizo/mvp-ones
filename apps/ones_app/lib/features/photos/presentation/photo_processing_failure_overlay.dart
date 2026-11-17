import 'package:flutter/material.dart';

class PhotoProcessingFailureOverlay extends StatelessWidget {
  final String message;
  final bool canRetry;
  final bool retryPending;
  final String retryLabel;
  final String retryingLabel;
  final VoidCallback? onRetry;

  const PhotoProcessingFailureOverlay({
    super.key,
    required this.message,
    required this.canRetry,
    required this.retryPending,
    required this.retryLabel,
    required this.retryingLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (canRetry)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: retryPending ? null : onRetry,
                    child: Text(
                      retryPending ? retryingLabel : retryLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
