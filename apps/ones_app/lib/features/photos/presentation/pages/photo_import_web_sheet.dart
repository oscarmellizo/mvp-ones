import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/media/photo_metadata_extractor.dart';
import '../../../../core/media/png_to_jpeg.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../adapters/api/event_photos_api.dart';

class PhotoImportWebSheet extends StatefulWidget {
  final String eventId;
  const PhotoImportWebSheet({super.key, required this.eventId});

  @override
  State<PhotoImportWebSheet> createState() => _PhotoImportWebSheetState();
}

class _PhotoImportWebSheetState extends State<PhotoImportWebSheet> {
  static const int _maxFiles = 15;
  final _extractor = const PhotoMetadataExtractor();

  List<PlatformFile> _files = const [];
  final Map<String, double> _progress = {};
  bool _uploading = false;
  Object? _error;

  Future<void> _pick() async {
    setState(() => _error = null);
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
    );
    if (res == null) return;
    var items = res.files.where((f) => (f.bytes != null || (f.path ?? '').isNotEmpty)).toList(growable: false);
    if (items.length > _maxFiles) {
      items = items.sublist(0, _maxFiles);
    }
    setState(() => _files = items);
  }

  Future<void> _startUpload() async {
    if (_files.isEmpty || _uploading) return;

    setState(() => _uploading = true);

    try {
      final api = context.read<EventPhotosApi>();
      final t = context.read<TranslationsService>();

      Future<void> uploadOne(PlatformFile f) async {
        try {
          final name = f.name;
          final ext = name.split('.').last.toLowerCase();
          Uint8List bytes = f.bytes ?? Uint8List.fromList([]);
          if (bytes.isEmpty) return;

          if (ext == 'png') {
            bytes = await compute(pngToJpegBytes, bytes);
          }

          final createdAt = await _extractor.createdAtFromBytes(
            bytes: bytes,
            filename: name,
          );

          final photoId = DateTime.now().microsecondsSinceEpoch.toString() + name.hashCode.toUnsigned(20).toString();

          final presign = await api.presignPut(
            eventId: widget.eventId,
            photoId: photoId,
            contentType: 'image/jpeg',
          );

          await api.uploadBytesToPresignedUrl(
            putUrl: presign.putUrl,
            bytes: bytes,
            contentType: 'image/jpeg',
            onProgress: (sent, total) {
              if (!mounted) return;
              setState(() {
                _progress[name] = total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.0;
              });
            },
          );

          await api.complete(
            eventId: widget.eventId,
            photoId: photoId,
            s3KeyOriginal: presign.s3KeyOriginal,
            createdAt: createdAt.toUtc().toIso8601String(),
          );

          setState(() => _progress[name] = 1.0);
        } catch (e) {
          setState(() => _progress[f.name] = -1);
        }
      }

      final files = _files;
      for (final f in files) {
        _progress[f.name] = 0.0;
      }
      setState(() {});

      // Limited concurrency: up to 4 parallel uploads
      final queue = List<PlatformFile>.from(files);
      final workers = <Future<void>>[];
      final poolSize = queue.length < 4 ? queue.length : 4;
      Future<void> worker() async {
        while (true) {
          PlatformFile? f;
          if (queue.isEmpty) break;
          f = queue.removeLast();
          await uploadOne(f);
        }
      }
      for (var i = 0; i < poolSize; i++) {
        workers.add(worker());
      }
      await Future.wait(workers);

      if (!mounted) return;
      if (_progress.values.any((v) => v < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.translate('event_detail.upload_failed', fallback: 'Algunas fotos fallaron al subir'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.translate('event_detail.upload_done', fallback: 'Fotos subidas'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final authed = context.select<AuthController, bool>((a) => a.isSignedIn);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.translate('event_detail.action_upload_photos', fallback: 'Subir fotos'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: _uploading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.translate('event_detail.upload_limit_hint', fallback: 'Selecciona hasta 15 imágenes (JPG o PNG).'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _uploading ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(t.translate('event_detail.action_pick', fallback: 'Elegir')),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (!_uploading && authed && _files.isNotEmpty) ? _startUpload : null,
                  child: Text(t.translate('event_detail.action_upload', fallback: 'Subir')),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text('${t.translate('common.error', fallback: 'Error')}: $_error', style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _files.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = _files[i];
                  final name = f.name;
                  final sizeKb = (f.size / 1024).toStringAsFixed(1);
                  final p = _progress[name];
                  return ListTile(
                    dense: true,
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('$sizeKb KB'),
                    trailing: () {
                      if (p == null) return const SizedBox.shrink();
                      if (p < 0) return const Icon(Icons.error_outline, color: Colors.red);
                      if (p >= 1.0) return const Icon(Icons.check_circle, color: Colors.green);
                      return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
                    }(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
