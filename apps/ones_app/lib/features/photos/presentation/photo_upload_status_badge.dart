import 'package:flutter/material.dart';

class PhotoUploadStatusBadge extends StatelessWidget {
  final String status;
  final double? progress;
  final VoidCallback? onRetry;

  const PhotoUploadStatusBadge({
    super.key,
    required this.status,
    this.progress,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final failed = normalized == 'failed';
    final localFileMissing = normalized == 'missing_file';
    final uploading = normalized == 'uploading';
    final processing =
        const {'uploaded', 'processing', 'retrying'}.contains(normalized);
    final safeProgress = progress?.clamp(0.0, 1.0).toDouble();
    final label = switch (normalized) {
      'failed' => 'Error al subir. Toca para reintentar.',
      'missing_file' =>
        'La foto ya no está en el dispositivo; vuelve a importarla.',
      'uploading' => safeProgress == null
          ? 'Subiendo foto'
          : 'Subiendo foto: ${(safeProgress * 100).round()}%',
      'uploaded' ||
      'processing' ||
      'retrying' =>
        'Foto subida; procesando en el servidor',
      _ => 'Foto guardada en el dispositivo; pendiente de subir',
    };

    final icon = failed || localFileMissing
        ? Icons.error_outline
        : processing
            ? Icons.sync
            : Icons.cloud_upload_outlined;
    final background =
        failed || localFileMissing ? Colors.red.shade700 : Colors.black87;

    return Semantics(
      label: label,
      button: failed && onRetry != null,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: failed ? onRetry : null,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (uploading)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      value: safeProgress,
                      strokeWidth: 2,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: Colors.white),
                if (uploading && safeProgress != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '${(safeProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
