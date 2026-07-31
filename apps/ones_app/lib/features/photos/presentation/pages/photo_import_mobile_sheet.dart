import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/media/photo_metadata_extractor.dart';
import '../../../../core/media/png_to_jpeg.dart';
import '../../adapters/local/photo_storage.dart';
import '../../presentation/photos_upload_controller.dart';

class PhotoImportMobileSheet extends StatefulWidget {
  final String eventId;
  const PhotoImportMobileSheet({super.key, required this.eventId});

  @override
  State<PhotoImportMobileSheet> createState() => _PhotoImportMobileSheetState();
}

class _PhotoImportMobileSheetState extends State<PhotoImportMobileSheet> {
  static const int _maxFiles = 15;
  final _picker = ImagePicker();
  final _extractor = const PhotoMetadataExtractor();

  List<XFile> _files = const [];
  bool _picking = false;
  bool _uploading = false;
  Object? _error;

  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final images = await _picker.pickMultiImage();
      if (images == null) return;
      var items = images;
      if (items.length > _maxFiles) {
        items = items.sublist(0, _maxFiles);
      }
      setState(() => _files = items);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _picking = false);
    }
  }

  Future<void> _startEnqueue() async {
    if (_files.isEmpty || _uploading) return;
    setState(() => _uploading = true);

    try {
      final uploader = context.read<PhotosUploadController>();
      final storage = context.read<PhotoStorage>();
      final t = context.read<TranslationsService>();

      for (final xf in _files) {
        final name = xf.name.toLowerCase();
        final path = xf.path;
        if (path.isEmpty) continue;
        File file = File(path);
        Uint8List? bytes;

        if (name.endsWith('.png')) {
          bytes = await xf.readAsBytes();
          final jpgBytes = await compute(pngToJpegBytes, bytes);
          final tmp = await _writeTempJpeg(jpgBytes, baseName: name);
          file = tmp;
        }

        final createdAt = await _extractor.createdAtFromFile(file: file, filename: name);
        final photoId = DateTime.now().microsecondsSinceEpoch.toString() + name.hashCode.toUnsigned(20).toString();

        await uploader.enqueueCapturedJpeg(
          eventId: widget.eventId,
          photoId: photoId,
          capturedFile: file,
          createdAt: createdAt,
          frameId: null,
          orientation: null,
          cameraType: 'import',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('event_detail.upload_started', fallback: 'Subida en progreso'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<File> _writeTempJpeg(Uint8List bytes, {required String baseName}) async {
    final dir = await Directory.systemTemp.createTemp('ones_import_');
    final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${baseName.replaceAll(".png", ".jpg")}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();

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
                  onPressed: _picking || _uploading ? null : _pick,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(t.translate('event_detail.action_pick', fallback: 'Elegir')),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: (!_uploading && _files.isNotEmpty) ? _startEnqueue : null,
                  child: Text(t.translate('event_detail.action_upload', fallback: 'Cargar fotos')),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text('${t.translate('common.error', fallback: 'Error')}: $_error', style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _files.length,
                itemBuilder: (context, i) {
                  final xf = _files[i];
                  final file = File(xf.path);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: _uploading
                              ? null
                              : () {
                                  setState(() {
                                    final next = List<XFile>.from(_files);
                                    next.removeAt(i);
                                    _files = next;
                                  });
                                },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
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
