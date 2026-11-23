import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/media/photo_date_resolution.dart';
import '../../../../core/media/ios_photo_library_picker.dart';
import '../../../../core/media/png_to_jpeg.dart';
import '../../presentation/photos_upload_controller.dart';
import 'photo_import_file_utils.dart';

class PhotoImportMobileSheet extends StatefulWidget {
  final String eventId;
  const PhotoImportMobileSheet({super.key, required this.eventId});

  @override
  State<PhotoImportMobileSheet> createState() => _PhotoImportMobileSheetState();
}

class _PhotoImportMobileSheetState extends State<PhotoImportMobileSheet> {
  static const int _maxFiles = 15;
  final _dateResolver = const PhotoDateResolver();
  final _imagePicker = ImagePicker();
  final _iosPhotoLibraryPicker = IosPhotoLibraryPicker();

  List<PlatformFile> _files = const [];
  bool _picking = false;
  bool _uploading = false;
  Object? _error;

  bool get _usesIosPhotoLibrary =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _pick() => _pickWith(
        _usesIosPhotoLibrary ? _pickFromPhotoLibrary : _pickFromFiles,
      );

  Future<void> _pickFiles() => _pickWith(_pickFromFiles);

  Future<void> _pickWith(
    Future<List<PlatformFile>?> Function() picker,
  ) async {
    if (_picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final selected = await picker();
      if (selected == null || selected.isEmpty || !mounted) return;
      setState(() => _files = selected.take(_maxFiles).toList(growable: false));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<List<PlatformFile>?> _pickFromPhotoLibrary() async {
    try {
      final photos = await _iosPhotoLibraryPicker.pickImages(limit: _maxFiles);
      return Future.wait(
        photos.map(
          (photo) async => PlatformFile(
            name: photo.name,
            size: await File(photo.path).length(),
            path: photo.path,
          ),
        ),
      );
    } on MissingPluginException {
      // Keep the existing picker available on older app installations.
    } on PlatformException {
      // Keep the existing picker available if the native picker is unsupported.
    }

    final photos = await _imagePicker.pickMultiImage(
      imageQuality: 100,
      requestFullMetadata: true,
    );
    if (photos.isEmpty) return null;

    return Future.wait(
      photos.map(
        (photo) async => PlatformFile(
          name: photo.name,
          size: await photo.length(),
          path: photo.path,
        ),
      ),
    );
  }

  Future<List<PlatformFile>?> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    return result?.files;
  }

  Future<void> _startEnqueue() async {
    if (_files.isEmpty || _uploading) return;
    setState(() => _uploading = true);

    try {
      final uploader = context.read<PhotosUploadController>();
      final t = context.read<TranslationsService>();

      for (final pf in _files) {
        final originalFilename = pf.name;
        final name = originalFilename.toLowerCase();
        final ext = name.split('.').last;

        Uint8List bytes;
        if (pf.bytes != null && pf.bytes!.isNotEmpty) {
          bytes = pf.bytes!;
        } else if ((pf.path ?? '').isNotEmpty) {
          bytes = await File(pf.path!).readAsBytes();
        } else {
          continue;
        }

        // Compute createdAt from original bytes + original filename to preserve WhatsApp patterns
        final dateResolution = await _dateResolver.resolveFromBytes(
          bytes: bytes,
          filename: originalFilename,
        );

        // Store every supported image as JPEG before enqueueing it.
        File file;
        if (ext != 'jpg' && ext != 'jpeg') {
          Uint8List jpgBytes;
          try {
            jpgBytes = await compute(pngToJpegBytes, bytes);
          } catch (_) {
            // Formats the `image` package can't decode (e.g. HEIC from the
            // iOS photo library) still decode via the platform codec.
            jpgBytes = await platformImageToJpegBytes(bytes);
          }
          file = await _writeTempJpeg(jpgBytes, baseName: name);
        } else if ((pf.path ?? '').isNotEmpty) {
          file = File(pf.path!);
        } else {
          file = await _writeTempJpeg(bytes, baseName: name);
        }

        final photoId = DateTime.now().microsecondsSinceEpoch.toString() +
            name.hashCode.toUnsigned(20).toString();

        await uploader.enqueueCapturedJpeg(
          eventId: widget.eventId,
          photoId: photoId,
          capturedFile: file,
          createdAt: dateResolution.createdAt,
          originalFilename: originalFilename,
          metadataCreatedAt: dateResolution.metadataDate,
          filenameCreatedAt: dateResolution.filenameDate,
          createdAtSource: dateResolution.source,
          deviceUtcOffsetMinutes: dateResolution.deviceUtcOffsetMinutes,
          frameId: null,
          orientation: null,
          cameraType: 'import',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(t.translate('event_detail.upload_started',
                fallback: 'Subida en progreso'))),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<File> _writeTempJpeg(Uint8List bytes,
      {required String baseName}) async {
    final dir = await Directory.systemTemp.createTemp('ones_import_');
    final fileName = jpegImportFileName(baseName);
    final file = File(
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$fileName',
    );
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
                    t.translate('event_detail.action_upload_photos',
                        fallback: 'Subir fotos'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed:
                      _uploading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.translate('event_detail.upload_limit_hint',
                  fallback: 'Selecciona hasta 15 imágenes (JPG o PNG).'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _picking || _uploading ? null : _pick,
                  icon: Icon(
                    _usesIosPhotoLibrary
                        ? Icons.photo_library_outlined
                        : Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    _usesIosPhotoLibrary
                        ? t.translate(
                            'event_detail.action_pick_gallery',
                            fallback: 'Galería',
                          )
                        : t.translate(
                            'event_detail.action_pick',
                            fallback: 'Elegir',
                          ),
                  ),
                ),
                if (_usesIosPhotoLibrary)
                  OutlinedButton.icon(
                    onPressed: _picking || _uploading ? null : _pickFiles,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      t.translate(
                        'event_detail.action_pick_files',
                        fallback: 'Archivos',
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed:
                      (!_uploading && _files.isNotEmpty) ? _startEnqueue : null,
                  child: Text(t.translate('event_detail.action_upload',
                      fallback: 'Cargar fotos')),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text('${t.translate('common.error', fallback: 'Error')}: $_error',
                  style: const TextStyle(color: Colors.red)),
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
                  final pf = _files[i];
                  final hasPath = (pf.path ?? '').isNotEmpty;
                  final hasBytes = pf.bytes != null && pf.bytes!.isNotEmpty;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: hasPath
                              ? Image.file(
                                  File(pf.path!),
                                  fit: BoxFit.cover,
                                )
                              : hasBytes
                                  ? Image.memory(
                                      pf.bytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox(),
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
                                    final next =
                                        List<PlatformFile>.from(_files);
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
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.red),
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
