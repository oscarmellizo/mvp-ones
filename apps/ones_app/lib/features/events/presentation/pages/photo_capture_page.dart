import 'package:flutter/material.dart';

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../photos/presentation/photos_upload_controller.dart';

class PhotoCapturePage extends StatefulWidget {
  final String eventId;

  const PhotoCapturePage({super.key, required this.eventId});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _initializing = true;
  Object? _error;
  bool _disposed = false;
  bool _switchingCamera = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    if (kIsWeb) {
      setState(() {
        _initializing = false;
        _error =
            'Camera preview is not supported on Web yet. Please use Android/iOS.';
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

  static int _pickDefaultCameraIndex(List<CameraDescription> cams) {
    final back =
        cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    return back >= 0 ? back : 0;
  }

  Future<void> _startController(CameraDescription description) async {
    if (_disposed) return;
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final next = CameraController(
      description,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _controller = next;
    await next.initialize();
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
      final controller = _controller;
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                            error: 'Camera not initialized',
                            onRetry: _init,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isPortrait =
                                  MediaQuery.orientationOf(context) ==
                                      Orientation.portrait;

                              final previewAspectRatio = isPortrait
                                  ? (1 / controller.value.aspectRatio)
                                  : controller.value.aspectRatio;

                              return Center(
                                child: AspectRatio(
                                  aspectRatio: previewAspectRatio,
                                  child: CameraPreview(controller),
                                ),
                              );
                            },
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
            child: IconButton(
              onPressed: _initializing ? null : _switchCamera,
              icon: const Icon(Icons.cameraswitch, color: Colors.white),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
            child: Center(
              child: IconButton(
                onPressed: (_initializing || _capturing || _error != null)
                    ? null
                    : () => _captureAndEnqueue(context),
                iconSize: 72,
                icon: Icon(
                  Icons.radio_button_checked,
                  color: (_initializing || _capturing || _error != null)
                      ? Colors.white54
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndEnqueue(BuildContext context) async {
    if (kIsWeb) return;

    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    final uploader = context.read<PhotosUploadController>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _capturing = true;
    });

    try {
      final file = await cam.takePicture();
      final photoId = const Uuid().v4();

      await uploader.enqueueCapturedJpeg(
        eventId: widget.eventId,
        photoId: photoId,
        capturedFile: File(file.path),
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Foto guardada y en cola para subir')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error capturando foto: $e')),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            Text(
              'Camera error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
