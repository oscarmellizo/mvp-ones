import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../photos/presentation/photos_upload_controller.dart';
import '../../adapters/api/event_templates_api_repository.dart';

class PhotoCapturePage extends StatefulWidget {
  final String eventId;

  final List<String> frameIds;

  const PhotoCapturePage(
      {super.key, required this.eventId, this.frameIds = const <String>[]});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage>
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

  String? _lastLanguage;

  bool _framesEnabled = false;
  List<TemplateFrame> _framePairs = const [];
  int _currentFrameIndex = 0;
  bool _loadingFrames = false;
  Object? _framesError;

  final Map<String, Uint8List> _frameBytesCache = {};

  late AnimationController _shutterAnimationController;
  late Animation<double> _shutterOpacityAnimation;

  bool _shutterSoundEnabled = true;
  bool _shutterHapticEnabled = true;

  static const Set<String> _photoCaptureRequiredKeys = {
    'photo_capture.error_web_not_supported',
    'photo_capture.error_camera_not_initialized',
    'photo_capture.frames_loading',
    'photo_capture.frames_error',
    'photo_capture.error_capture_failed',
    'photo_capture.camera_error',
    'photo_capture.retry',
  };

  Object _formatError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map) {
        final code = data['code'] ?? data['error'];
        final msg = data['message'];
        return 'HTTP $status ${code ?? ''} ${msg ?? ''}'.trim();
      }
      if (data is String && data.trim().isNotEmpty) {
        return 'HTTP $status ${data.trim()}'.trim();
      }
      return 'HTTP $status ${error.message ?? 'Request failed'}'.trim();
    }
    return error;
  }

  @override
  void initState() {
    super.initState();
    _lastLanguage = context.read<TranslationsService>().getCurrentLanguage();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'photo_capture',
            requiredKeys: _photoCaptureRequiredKeys,
          );
    });

    _init();
    _loadFrames();
    _loadShutterPreferences();

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
  }

  Future<void> _init() async {
    if (kIsWeb) {
      final t = context.read<TranslationsService>();
      setState(() {
        _initializing = false;
        _error = t.translate(
          'photo_capture.error_web_not_supported',
          fallback:
              'Camera preview is not supported on Web yet. Please use Android/iOS.',
        );
      });
      return;
    }
    if (_disposed) return;
    setState(() {
      _initializing = true;
      _error = null;
    });

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
      _switchingCamera = false;
      if (mounted && !_disposed) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _loadFrames() async {
    if (!mounted) return;
    if (widget.frameIds.isEmpty) return;

    setState(() {
      _loadingFrames = true;
      _framesError = null;
      _framePairs = const [];
      _currentFrameIndex = 0;
    });

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
        if (f != null &&
            f.verticalUrl != null &&
            f.verticalUrl!.isNotEmpty &&
            f.horizontalUrl != null &&
            f.horizontalUrl!.isNotEmpty) {
          ordered.add(f);
        }
      }

      if (!mounted) return;
      setState(() {
        _framePairs = List<TemplateFrame>.unmodifiable(ordered);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _framesError = _formatError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFrames = false;
        });
      }
    }
  }

  Future<void> _loadShutterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _shutterSoundEnabled =
            prefs.getBool('ones.camera.shutterSoundEnabled') ?? true;
        _shutterHapticEnabled =
            prefs.getBool('ones.camera.shutterHapticEnabled') ?? true;
      });
    } catch (_) {
      // If SharedPreferences fails, keep defaults
    }
  }

  Future<void> _saveShutterPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          'ones.camera.shutterSoundEnabled', _shutterSoundEnabled);
      await prefs.setBool(
          'ones.camera.shutterHapticEnabled', _shutterHapticEnabled);
    } catch (_) {
      // If SharedPreferences fails, ignore
    }
  }

  void _showShutterSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ajustes de obturador',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text(
                    'Sonido de obturador',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Reproducir sonido al tomar foto',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: _shutterSoundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _shutterSoundEnabled = value;
                    });
                    _saveShutterPreferences();
                  },
                ),
                SwitchListTile(
                  title: const Text(
                    'Vibración (haptic)',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Vibración al tomar foto',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: _shutterHapticEnabled,
                  onChanged: (value) {
                    setState(() {
                      _shutterHapticEnabled = value;
                    });
                    _saveShutterPreferences();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _downloadBytesCached(String url) async {
    final cached = _frameBytesCache[url];
    if (cached != null) return cached;

    final req = await HttpClient().getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Failed to download overlay: $url (${res.statusCode})');
    }
    final bytes = await consolidateHttpClientResponseBytes(res);
    _frameBytesCache[url] = bytes;
    return bytes;
  }

  Future<File> _composeJpegWithOverlay({
    required File photo,
    required String overlayUrl,
    required bool mirrorHorizontally,
    required double targetAspectRatio,
    required DeviceOrientation? deviceOrientation,
  }) async {
    final photoBytes = await photo.readAsBytes();
    final overlayBytes = await _downloadBytesCached(overlayUrl);

    final base = img.decodeImage(photoBytes);
    if (base == null) {
      throw StateError('Failed to decode captured photo');
    }
    final overlay = img.decodeImage(overlayBytes);
    if (overlay == null) {
      throw StateError('Failed to decode overlay image');
    }

    img.Image composed = img.bakeOrientation(base);
    composed = _rotateToMatchAspect(
      composed,
      targetAspectRatio,
      deviceOrientation: deviceOrientation,
      invertLandscapeRotation: mirrorHorizontally,
    );
    if (mirrorHorizontally) {
      composed = img.flipHorizontal(composed);
    }

    composed = _centerCropToAspect(composed, targetAspectRatio);
    final resized = img.copyResize(
      overlay,
      width: composed.width,
      height: composed.height,
      interpolation: img.Interpolation.average,
    );

    img.compositeImage(composed, resized, dstX: 0, dstY: 0);

    final outBytes = img.encodeJpg(composed, quality: 92);
    final dir = await Directory.systemTemp.createTemp('ones_composed_');
    final out = File('${dir.path}/${const Uuid().v4()}.jpg');
    await out.writeAsBytes(outBytes, flush: true);
    return out;
  }

  static img.Image _rotateToMatchAspect(
    img.Image src,
    double targetAspect, {
    required DeviceOrientation? deviceOrientation,
    required bool invertLandscapeRotation,
  }) {
    if (targetAspect <= 0) return src;

    final isTargetLandscape = targetAspect >= 1;
    final isSrcLandscape = src.width >= src.height;

    if (isTargetLandscape == isSrcLandscape) return src;

    final int angle = switch (deviceOrientation) {
      DeviceOrientation.landscapeLeft => invertLandscapeRotation ? 90 : 270,
      DeviceOrientation.landscapeRight => invertLandscapeRotation ? 270 : 90,
      _ => 90,
    };
    return img.copyRotate(src, angle: angle);
  }

  static img.Image _centerCropToAspect(img.Image src, double aspectRatio) {
    if (aspectRatio <= 0) return src;
    final srcW = src.width;
    final srcH = src.height;
    if (srcW <= 0 || srcH <= 0) return src;

    final srcAspect = srcW / srcH;
    if ((srcAspect - aspectRatio).abs() < 0.0001) {
      return src;
    }

    if (srcAspect > aspectRatio) {
      final targetW = (srcH * aspectRatio).round().clamp(1, srcW);
      final x = ((srcW - targetW) / 2).round();
      return img.copyCrop(src, x: x, y: 0, width: targetW, height: srcH);
    }

    final targetH = (srcW / aspectRatio).round().clamp(1, srcH);
    final y = ((srcH - targetH) / 2).round();
    return img.copyCrop(src, x: 0, y: y, width: srcW, height: targetH);
  }

  static int _pickDefaultCameraIndex(List<CameraDescription> cams) {
    final back =
        cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    return back >= 0 ? back : 0;
  }

  Future<void> _startController(CameraDescription description) async {
    if (_disposed) return;
    final epoch = ++_controllerEpoch;

    final old = _controller;
    _controller = null;
    if (mounted && !_disposed) {
      setState(() {});
    }
    await old?.dispose();
    if (_disposed || epoch != _controllerEpoch) return;

    final next = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _controller = next;
    try {
      await next.initialize();
    } catch (e) {
      final cancelled = _disposed || epoch != _controllerEpoch;
      if (epoch == _controllerEpoch) {
        _controller = null;
      }
      await next.dispose();
      if (cancelled) {
        return;
      }
      rethrow;
    }

    if (_disposed || epoch != _controllerEpoch) {
      await next.dispose();
      return;
    }

    if (mounted && !_disposed) {
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (kIsWeb) return;
    if (_initializing || _switchingCamera) return;
    if (_cameras.isEmpty) return;

    try {
      _switchingCamera = true;
      setState(() {
        _error = null;
        _initializing = true;
      });

      final current = _cameras[_cameraIndex];
      final preferredDirection =
          current.lensDirection == CameraLensDirection.back
              ? CameraLensDirection.front
              : CameraLensDirection.back;

      final nextIndex = _cameras.indexWhere(
        (c) => c.lensDirection == preferredDirection,
      );

      _cameraIndex =
          nextIndex >= 0 ? nextIndex : (_cameraIndex + 1) % _cameras.length;
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      _error = e;
    } finally {
      _switchingCamera = false;
      if (mounted && !_disposed) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (state == AppLifecycleState.inactive) {
      _controllerEpoch++;
      final controller = _controller;
      _controller = null;
      if (mounted && !_disposed) {
        setState(() {
          _initializing = true;
          _error = null;
        });
      }
      unawaited(controller?.dispose());
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controllerEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    _shutterAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final lang = t.getCurrentLanguage();
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'photo_capture',
              requiredKeys: _photoCaptureRequiredKeys,
            );
      });
    }
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _initializing
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? _CameraErrorView(
                        error: _error,
                        onRetry: _init,
                      )
                    : (controller == null || !controller.value.isInitialized)
                        ? _CameraErrorView(
                            error: context
                                .read<TranslationsService>()
                                .translate(
                                  'photo_capture.error_camera_not_initialized',
                                  fallback: 'Camera not initialized',
                                ),
                            onRetry: _init,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isPortrait =
                                  MediaQuery.orientationOf(context) ==
                                      Orientation.portrait;

                              final effectiveAspect = isPortrait
                                  ? (1 / controller.value.aspectRatio)
                                  : controller.value.aspectRatio;
                              final screenAspect =
                                  constraints.maxWidth / constraints.maxHeight;
                              final rawScale = effectiveAspect / screenAspect;
                              final scale =
                                  rawScale < 1 ? 1 / rawScale : rawScale;

                              return ClipRect(
                                child: Transform.scale(
                                  scale: scale,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: effectiveAspect,
                                      child: CameraPreview(controller),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          AnimatedBuilder(
            animation: _shutterAnimationController,
            builder: (context, child) {
              return Opacity(
                opacity: _shutterOpacityAnimation.value,
                child: Container(
                  color: Colors.black,
                ),
              );
            },
          ),
          if (_framePairs.isNotEmpty && _framesEnabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Builder(
                  builder: (context) {
                    final orientation = MediaQuery.orientationOf(context) ==
                            Orientation.portrait
                        ? Orientation.portrait
                        : Orientation.landscape;
                    final controller = _controller;
                    if (controller == null || !controller.value.isInitialized) {
                      return const SizedBox.shrink();
                    }
                    final frame =
                        _framePairs[_currentFrameIndex % _framePairs.length];
                    final url = orientation == Orientation.portrait
                        ? frame.verticalUrl
                        : frame.horizontalUrl;
                    if (url == null || url.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Image.network(
                      url,
                      fit: BoxFit.fill,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
                      },
                    );
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
                  onPressed: _showShutterSettings,
                  icon: const Icon(Icons.settings, color: Colors.white),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _initializing ? null : _switchCamera,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                ),
              ],
            ),
          ),
          if (widget.frameIds.isNotEmpty && _loadingFrames)
            Positioned(
              left: 12,
              right: 12,
              top: 60 + MediaQuery.paddingOf(context).top,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: Colors.black.withOpacity(0.45),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.read<TranslationsService>().translate(
                            'photo_capture.frames_loading',
                            fallback: 'Cargando frames…',
                          ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.frameIds.isNotEmpty &&
              !_loadingFrames &&
              _framesError != null)
            Positioned(
              left: 12,
              right: 12,
              top: 60 + MediaQuery.paddingOf(context).top,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: Colors.red.withOpacity(0.6),
                child: Text(
                  '${context.read<TranslationsService>().translate(
                        "photo_capture.frames_error",
                        fallback: 'Error cargando frames',
                      )}: $_framesError',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
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
                    onPressed: () {
                      setState(() {
                        _framesEnabled = !_framesEnabled;
                      });
                    },
                    icon: Icon(
                      _framesEnabled
                          ? Icons.filter_frames
                          : Icons.filter_frames_outlined,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_framePairs.length > 1) ...[
                    IconButton(
                      onPressed: () {
                        setState(() {
                          final len = _framePairs.length;
                          _currentFrameIndex =
                              (_currentFrameIndex - 1 + len) % len;
                        });
                      },
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Text(
                      '${_currentFrameIndex + 1}/${_framePairs.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          final len = _framePairs.length;
                          _currentFrameIndex = (_currentFrameIndex + 1) % len;
                        });
                      },
                      icon:
                          const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          Builder(
            builder: (context) {
              final isPortrait =
                  MediaQuery.orientationOf(context) == Orientation.portrait;
              final isDisabled = _initializing || _capturing || _error != null;

              if (isPortrait) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  child: Center(
                    child: IconButton(
                      onPressed:
                          isDisabled ? null : () => _captureAndEnqueue(context),
                      iconSize: 72,
                      icon: Icon(
                        Icons.radio_button_checked,
                        color: isDisabled ? Colors.white54 : Colors.white,
                      ),
                    ),
                  ),
                );
              } else {
                return Stack(
                  children: [
                    Positioned(
                      left: 24,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: isDisabled
                              ? null
                              : () => _captureAndEnqueue(context),
                          iconSize: 72,
                          icon: Icon(
                            Icons.radio_button_checked,
                            color: isDisabled ? Colors.white54 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 24,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: isDisabled
                              ? null
                              : () => _captureAndEnqueue(context),
                          iconSize: 72,
                          icon: Icon(
                            Icons.radio_button_checked,
                            color: isDisabled ? Colors.white54 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndEnqueue(BuildContext context) async {
    if (kIsWeb) return;

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final size = MediaQuery.sizeOf(context);
    final targetAspectRatio = size.width / size.height;

    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    final uploader = context.read<PhotosUploadController>();

    setState(() {
      _capturing = true;
    });

    try {
      if (_shutterHapticEnabled) {
        HapticFeedback.lightImpact();
      }
      if (_shutterSoundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }
      await _shutterAnimationController.forward();
      await _shutterAnimationController.reverse();

      final deviceOrientation = cam.value.deviceOrientation;
      final file = await cam.takePicture();
      final photoId = const Uuid().v4();

      final lensDirection =
          _cameras.isNotEmpty ? _cameras[_cameraIndex].lensDirection : null;
      final isFront = lensDirection == CameraLensDirection.front;

      File captured = File(file.path);
      String? usedFrameId;

      if (_framesEnabled && _framePairs.isNotEmpty) {
        final frame = _framePairs[_currentFrameIndex % _framePairs.length];
        final url = isPortrait ? frame.verticalUrl : frame.horizontalUrl;
        if (url != null && url.isNotEmpty) {
          usedFrameId = frame.frameId;
          captured = await _composeJpegWithOverlay(
            photo: captured,
            overlayUrl: url,
            mirrorHorizontally: isFront,
            targetAspectRatio: targetAspectRatio,
            deviceOrientation: deviceOrientation,
          );
        }
      }

      if (kDebugMode) {
        debugPrint(
          'photo_capture: eventId=$widget.eventId photoId=$photoId frameId=${usedFrameId ?? '-'} orientation=${isPortrait ? 'portrait' : 'landscape'} deviceOrientation=$deviceOrientation sensorOrientation=${cam.description.sensorOrientation} camera=${isFront ? 'front' : 'back'}',
        );
      }

      await uploader.enqueueCapturedJpeg(
        eventId: widget.eventId,
        photoId: photoId,
        capturedFile: captured,
        createdAt: DateTime.now(),
        frameId: usedFrameId,
        orientation: isPortrait ? 'portrait' : 'landscape',
        cameraType: isFront ? 'front' : 'back',
      );
    } catch (e) {
      if (!context.mounted) return;
      final t = context.read<TranslationsService>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t.translate(
                  "photo_capture.error_capture_failed",
                  fallback: 'Error capturando foto',
                )}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }
}

class _CameraErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _CameraErrorView({required this.error, required this.onRetry});

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
              '${t.translate(
                    "photo_capture.camera_error",
                    fallback: 'Camera error',
                  )}: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(
                t.translate(
                  'photo_capture.retry',
                  fallback: 'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
