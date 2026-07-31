import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../photos/adapters/api/event_photos_api.dart';
import '../../adapters/api/event_templates_api_repository.dart';
import 'capture_processing.dart';

class PhotoCaptureWebPage extends StatefulWidget {
  final String eventId;
  final List<String> frameIds;

  const PhotoCaptureWebPage({super.key, required this.eventId, this.frameIds = const <String>[]});

  @override
  State<PhotoCaptureWebPage> createState() => _PhotoCaptureWebPageState();
}

class _PhotoCaptureWebPageState extends State<PhotoCaptureWebPage> {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  Object? _error;
  bool _disposed = false;

  bool _framesEnabled = false;
  List<TemplateFrame> _framePairs = const [];
  int _currentFrameIndex = 0;
  bool _loadingFrames = false;
  Object? _framesError;

  final Map<String, Uint8List> _overlayCache = {};

  static const Set<String> _requiredKeys = {
    'photo_capture.error_web_not_supported',
    'photo_capture.frames_loading',
    'photo_capture.frames_error',
    'photo_capture.error_capture_failed',
    'photo_capture.retry',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'photo_capture',
            requiredKeys: _requiredKeys,
          );
    });
    _init();
    _loadFrames();
  }

  Future<void> _init() async {
    if (!kIsWeb) {
      setState(() { _initializing = false; });
      return;
    }
    setState(() { _initializing = true; _error = null; });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw StateError('No cameras available');
      }
      _cameraIndex = _pickDefaultCameraIndex(_cameras);
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      _error = e;
    } finally {
      if (mounted && !_disposed) {
        setState(() { _initializing = false; });
      }
    }
  }

  static int _pickDefaultCameraIndex(List<CameraDescription> cams) {
    final back = cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    return back >= 0 ? back : 0;
  }

  Future<void> _startController(CameraDescription description) async {
    if (_disposed) return;
    final old = _controller;
    _controller = null;
    if (mounted && !_disposed) setState(() {});
    await old?.dispose();

    final next = CameraController(description, ResolutionPreset.high, enableAudio: false);
    _controller = next;
    try {
      await next.initialize();
      if (mounted && !_disposed) setState(() {});
    } catch (e) {
      _controller = null;
      await next.dispose();
      rethrow;
    }
  }

  Future<void> _loadFrames() async {
    if (!mounted) return;
    if (widget.frameIds.isEmpty) return;
    setState(() { _loadingFrames = true; _framesError = null; _framePairs = const []; _currentFrameIndex = 0; });
    try {
      final templatesRepo = context.read<EventTemplatesApiRepository>();
      final templates = await templatesRepo.listTemplates();
      final byFrameId = <String, TemplateFrame>{};
      for (final t in templates) {
        for (final f in t.frames) {
          byFrameId[f.frameId] = f;
        }
      }
      final ordered = <TemplateFrame>[];
      for (final id in widget.frameIds) {
        final f = byFrameId[id];
        if (f != null && f.verticalUrl != null && f.verticalUrl!.isNotEmpty && f.horizontalUrl != null && f.horizontalUrl!.isNotEmpty) {
          ordered.add(f);
        }
      }
      if (!mounted) return;
      setState(() { _framePairs = List<TemplateFrame>.unmodifiable(ordered); });
    } catch (e) {
      if (!mounted) return;
      setState(() { _framesError = e; });
    } finally {
      if (mounted) setState(() { _loadingFrames = false; });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final t = context.watch<TranslationsService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _initializing
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? _ErrorView(error: _error, onRetry: _init)
                    : (controller == null || !controller.value.isInitialized)
                        ? _ErrorView(
                            error: t.translate('photo_capture.error_web_not_supported', fallback: 'Camera not ready'),
                            onRetry: _init,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
                              final effectiveAspect = isPortrait ? (1.0 / controller.value.aspectRatio) : controller.value.aspectRatio;
                              final screenAspect = constraints.maxWidth / constraints.maxHeight;
                              final rawScale = effectiveAspect / screenAspect;
                              final scale = rawScale < 1 ? 1 / rawScale : rawScale;
                              final isFront = _cameras.isNotEmpty ? _cameras[_cameraIndex].lensDirection == CameraLensDirection.front : false;

                              return ClipRect(
                                child: Transform.scale(
                                  scale: scale,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: effectiveAspect,
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..scale(isFront ? -1.0 : 1.0, 1.0),
                                        child: CameraPreview(controller),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          if (_framePairs.isNotEmpty && _framesEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Builder(
                  builder: (context) {
                    final orientation = MediaQuery.orientationOf(context) == Orientation.portrait ? Orientation.portrait : Orientation.landscape;
                    final controller = _controller;
                    if (controller == null || !controller.value.isInitialized) return const SizedBox.shrink();
                    final frame = _framePairs[_currentFrameIndex % _framePairs.length];
                    final url = orientation == Orientation.portrait ? frame.verticalUrl : frame.horizontalUrl;
                    if (url == null || url.isEmpty) return const SizedBox.shrink();
                    return Image.network(url, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox.shrink());
                  },
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 12 + MediaQuery.paddingOf(context).top,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Positioned(
            right: 12,
            top: 12 + MediaQuery.paddingOf(context).top,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _initializing ? null : _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),
          if (_framePairs.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 110 + MediaQuery.paddingOf(context).bottom,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () { setState(() { _framesEnabled = !_framesEnabled; }); },
                    icon: Icon(_framesEnabled ? Icons.filter_frames : Icons.filter_frames_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  if (_framePairs.length > 1) ...[
                    IconButton(
                      onPressed: () { setState(() { final len = _framePairs.length; _currentFrameIndex = (_currentFrameIndex - 1 + len) % len; }); },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      '${_currentFrameIndex + 1}/${_framePairs.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      onPressed: () { setState(() { final len = _framePairs.length; _currentFrameIndex = (_currentFrameIndex + 1) % len; }); },
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: IconButton(
                onPressed: _initializing || _error != null ? null : () => _captureAndUpload(context),
                iconSize: 72,
                icon: const Icon(Icons.radio_button_checked, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_initializing) return;
    if (_cameras.isEmpty) return;
    try {
      final current = _cameras[_cameraIndex];
      final preferred = current.lensDirection == CameraLensDirection.back ? CameraLensDirection.front : CameraLensDirection.back;
      final nextIndex = _cameras.indexWhere((c) => c.lensDirection == preferred);
      _cameraIndex = nextIndex >= 0 ? nextIndex : (_cameraIndex + 1) % _cameras.length;
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      setState(() { _error = e; });
    }
  }

  Future<Uint8List> _downloadOverlay(String url) async {
    final cached = _overlayCache[url];
    if (cached != null) return cached;
    final res = await Dio().get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    final bytes = Uint8List.fromList(res.data ?? const <int>[]);
    _overlayCache[url] = bytes;
    return bytes;
  }

  Future<void> _captureAndUpload(BuildContext context) async {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    try {
      final file = await cam.takePicture();
      Uint8List bytes = await file.readAsBytes();

      String? usedFrameId;
      final isPortrait = MediaQuery.orientationOf(context) == Orientation.portrait;
      final size = MediaQuery.sizeOf(context);
      final targetAspect = size.width / size.height;

      final lensDirection = _cameras.isNotEmpty ? _cameras[_cameraIndex].lensDirection : null;
      final isFront = lensDirection == CameraLensDirection.front;

      if (_framesEnabled && _framePairs.isNotEmpty) {
        final frame = _framePairs[_currentFrameIndex % _framePairs.length];
        final url = isPortrait ? frame.verticalUrl : frame.horizontalUrl;
        if (url != null && url.isNotEmpty) {
          usedFrameId = frame.frameId;
          final overlay = await _downloadOverlay(url);
          bytes = composeJpegWithOverlayBytes(
            baseJpegBytes: bytes,
            overlayImageBytes: overlay,
            mirrorHorizontally: isFront,
            targetAspectRatio: targetAspect,
          );
        }
      }

      final photoId = DateTime.now().microsecondsSinceEpoch.toString();
      final createdAt = DateTime.now().toUtc().toIso8601String();

      final api = context.read<EventPhotosApi>();
      final presign = await api.presignPut(
        eventId: widget.eventId,
        photoId: photoId,
        contentType: 'image/jpeg',
      );

      await api.uploadBytesToPresignedUrl(
        putUrl: presign.putUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      await api.complete(
        eventId: widget.eventId,
        photoId: photoId,
        s3KeyOriginal: presign.s3KeyOriginal,
        createdAt: createdAt,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final t = context.read<TranslationsService>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('photo_capture.error_capture_failed', fallback: 'Error capturando foto')}: $e'),
        ),
      );
    }
  }
}

class _ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            Text(
              '${t.translate('photo_capture.camera_error', fallback: 'Camera error')}: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(onPressed: onRetry, child: Text(t.translate('photo_capture.retry', fallback: 'Retry'))),
          ],
        ),
      ),
    );
  }
}
