import 'dart:async';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

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

class _PhotoCaptureWebPageState extends State<PhotoCaptureWebPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  Object? _error;
  bool _disposed = false;
  int _controllerEpoch = 0;
  bool _switchingCamera = false;
  bool _capturing = false;
  bool _uploading = false;
  CaptureOrientation? _orientationOverride;

  bool _framesEnabled = false;
  List<TemplateFrame> _framePairs = const [];
  int _currentFrameIndex = 0;
  bool _loadingFrames = false;
  Object? _framesError;

  final Map<String, Uint8List> _overlayCache = {};

  late AnimationController _shutterAnimationController;
  late Animation<double> _shutterOpacityAnimation;

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
    WidgetsBinding.instance.addObserver(this);
    _shutterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _shutterOpacityAnimation = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _shutterAnimationController,
        curve: Curves.easeInOut,
      ),
    );
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
    if (!kIsWeb || _disposed) return;
    final epoch = ++_controllerEpoch;
    setState(() { _initializing = true; _switchingCamera = false; _error = null; });
    try {
      final cameras = await availableCameras();
      if (!mounted || _disposed || epoch != _controllerEpoch) return;
      if (cameras.isEmpty) throw StateError('No cameras available');
      _cameras = cameras;
      _cameraIndex = _pickDefaultCameraIndex(cameras);
      await _startController(cameras[_cameraIndex], epoch);
    } catch (e) {
      if (mounted && !_disposed && epoch == _controllerEpoch) {
        _error = e;
      }
    } finally {
      if (mounted && !_disposed && epoch == _controllerEpoch) {
        setState(() { _initializing = false; });
      }
    }
  }

  static int _pickDefaultCameraIndex(List<CameraDescription> cams) {
    final back = cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    return back >= 0 ? back : 0;
  }

  Future<void> _startController(CameraDescription description, int epoch) async {
    if (_disposed || epoch != _controllerEpoch) return;
    final old = _controller;
    final preset = MediaQuery.sizeOf(context).shortestSide < 600
        ? ResolutionPreset.medium
        : ResolutionPreset.high;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    if (_disposed || epoch != _controllerEpoch) return;

    final next = CameraController(description, preset, enableAudio: false);
    try {
      await next.initialize();
      if (_disposed || epoch != _controllerEpoch) {
        await next.dispose();
        return;
      }
      _controller = next;
      if (mounted) setState(() {});
    } catch (e) {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controllerEpoch++;
      final previous = _controller;
      _controller = null;
      if (mounted) {
        setState(() {
          _initializing = true;
          _switchingCamera = false;
          if (!_uploading) _capturing = false;
        });
      }
      unawaited(previous?.dispose());
    } else if (state == AppLifecycleState.resumed && !_disposed) {
      unawaited(_init());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controllerEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    unawaited(c?.dispose());
    _shutterAnimationController.dispose();
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
                              final viewportAspect = constraints.maxWidth / constraints.maxHeight;
                              final orientation = resolveCaptureOrientation(
                                viewportAspect: viewportAspect,
                                deviceOrientation: controller.value.deviceOrientation,
                                forcedOrientation: _orientationOverride,
                              );
                              final effectiveAspect = orientation == CaptureOrientation.portrait
                                  ? (1.0 / controller.value.aspectRatio)
                                  : controller.value.aspectRatio;
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
                    final controller = _controller;
                    if (controller == null || !controller.value.isInitialized) return const SizedBox.shrink();
                    final size = MediaQuery.sizeOf(context);
                    final orientation = resolveCaptureOrientation(
                      viewportAspect: size.width / size.height,
                      deviceOrientation: controller.value.deviceOrientation,
                      forcedOrientation: _orientationOverride,
                    );
                    final frame = _framePairs[_currentFrameIndex % _framePairs.length];
                    final url = orientation == CaptureOrientation.portrait ? frame.verticalUrl : frame.horizontalUrl;
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
                  tooltip: _orientationOverride == null
                      ? 'Orientación automática'
                      : _orientationOverride == CaptureOrientation.landscape
                          ? 'Orientación horizontal'
                          : 'Orientación vertical',
                  onPressed: () => setState(() {
                    _orientationOverride = switch (_orientationOverride) {
                      null => CaptureOrientation.landscape,
                      CaptureOrientation.landscape => CaptureOrientation.portrait,
                      CaptureOrientation.portrait => null,
                    };
                  }),
                  icon: const Icon(Icons.screen_rotation, color: Colors.white),
                ),
                IconButton(
                  onPressed: _initializing || _switchingCamera || _capturing
                      ? null
                      : _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),
          if (_loadingFrames || _framesError != null)
            Positioned(
              top: 70 + MediaQuery.paddingOf(context).top,
              left: 12,
              right: 12,
              child: Center(
                child: Text(
                  _loadingFrames
                      ? t.translate('photo_capture.frames_loading', fallback: 'Cargando marcos…')
                      : '${t.translate('photo_capture.frames_error', fallback: 'Error cargando marcos')}: $_framesError',
                  style: const TextStyle(color: Colors.white),
                ),
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
                onPressed: _initializing || _switchingCamera || _capturing ||
                        _error != null || controller?.value.isInitialized != true
                    ? null
                    : () => _captureAndUpload(context),
                iconSize: 72,
                icon: const Icon(Icons.radio_button_checked, color: Colors.white),
              ),
            ),
          ),
          if (_capturing)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          // Shutter overlay animation
          CameraShutterOverlay(animation: _shutterOpacityAnimation),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_initializing || _switchingCamera || _capturing || _cameras.isEmpty) {
      return;
    }
    final epoch = ++_controllerEpoch;
    setState(() { _switchingCamera = true; _initializing = true; _error = null; });
    try {
      final current = _cameras[_cameraIndex];
      final preferred = current.lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final nextIndex = _cameras.indexWhere((c) => c.lensDirection == preferred);
      _cameraIndex = nextIndex >= 0 ? nextIndex : (_cameraIndex + 1) % _cameras.length;
      await _startController(_cameras[_cameraIndex], epoch);
    } catch (e) {
      if (mounted && epoch == _controllerEpoch) _error = e;
    } finally {
      if (mounted && epoch == _controllerEpoch) {
        setState(() { _switchingCamera = false; _initializing = false; });
      }
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
    if (_capturing || _switchingCamera || _initializing ||
        cam == null || !cam.value.isInitialized) {
      return;
    }
    final epoch = _controllerEpoch;
    final size = MediaQuery.sizeOf(context);
    final orientationOverride = _orientationOverride;
    final deviceOrientation = cam.value.deviceOrientation;
    final frame = _framesEnabled && _framePairs.isNotEmpty
        ? _framePairs[_currentFrameIndex % _framePairs.length]
        : null;
    final isFront = cam.description.lensDirection == CameraLensDirection.front;
    final api = context.read<EventPhotosApi>();
    setState(() { _capturing = true; });

    try {
      final file = await cam.takePicture();
      if (!mounted || epoch != _controllerEpoch) return;
      await _shutterAnimationController.forward();
      await _shutterAnimationController.reverse();
      if (!mounted || epoch != _controllerEpoch) return;
      final normalized = normalizeCapturedJpeg(
        bytes: await file.readAsBytes(),
        orientation: orientationOverride,
        viewportAspect: size.width / size.height,
        deviceOrientation: deviceOrientation,
        maxDimension: 2560,
      );
      Uint8List bytes = normalized.bytes;
      final url = normalized.orientation == CaptureOrientation.portrait
          ? frame?.verticalUrl
          : frame?.horizontalUrl;
      if (url != null && url.isNotEmpty) {
        final overlay = await _downloadOverlay(url);
        bytes = composeJpegWithOverlayBytes(
          baseJpegBytes: bytes,
          overlayImageBytes: overlay,
          mirrorHorizontally: isFront,
          targetAspectRatio: normalized.width / normalized.height,
        );
      }
      if (!context.mounted) return;

      final photoId = const Uuid().v4();
      final createdAt = DateTime.now().toUtc().toIso8601String();
      setState(() { _uploading = true; });
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

      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      final t = context.read<TranslationsService>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.translate('photo_capture.error_capture_failed', fallback: 'Error capturando foto')}: $e'),
        ),
      );
    } finally {
      if (mounted && (epoch == _controllerEpoch || _uploading)) {
        setState(() { _capturing = false; _uploading = false; });
      }
    }
  }
}

class CameraShutterOverlay extends StatelessWidget {
  final Animation<double> animation;

  const CameraShutterOverlay({super.key, required this.animation});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) => Opacity(
            opacity: animation.value,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      );
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
