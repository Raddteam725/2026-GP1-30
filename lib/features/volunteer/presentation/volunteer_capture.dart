import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'volunteer_components.dart';

/// In-app camera only, with explicit preview, retake and use-photo consent.
class VolunteerCapture extends StatefulWidget {
  const VolunteerCapture({super.key});
  @override
  State<VolunteerCapture> createState() => _VolunteerCaptureState();
}

class _VolunteerCaptureState extends State<VolunteerCapture>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Uint8List? _preview;
  bool _busy = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _operations = Future<void>.value();
  bool _foreground = true, _initializing = false;

  // CameraX owns shared native resources. Finish closing one controller before
  // creating the next, including when a permission dialog changes lifecycle.
  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.catchError((Object error) {
      debugPrint('Radd camera operation failed (${error.runtimeType})');
    });
    return operation;
  }

  Future<void> _closeCamera() async {
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      await camera.dispose();
    } catch (error) {
      // A failed initialization may leave CameraX without a preview surface.
      // Cleanup failure must not escape a lifecycle callback or block retry.
      debugPrint('Radd camera disposal failed (${error.runtimeType})');
    }
  }

  Future<void> _initialize() {
    final generation = ++_generation;
    return _enqueue(() async {
      await _closeCamera();
      if (!mounted || !_foreground || generation != _generation) return;
      _initializing = true;
      try {
        final cameras = await availableCameras();
        if (!mounted || !_foreground || generation != _generation) return;
        if (cameras.isEmpty) throw CameraException('NoCamera', '');
        final controller = CameraController(
          cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          ),
          ResolutionPreset.high,
          enableAudio: false,
        );
        _camera = controller;
        await controller.initialize();
        if (!mounted || !_foreground || generation != _generation) {
          await _closeCamera();
          return;
        }
        setState(() => _failed = false);
      } catch (error) {
        debugPrint(
          'Radd camera initialization failed: '
          '${error is CameraException ? error.code : error.runtimeType}',
        );
        await _closeCamera();
        if (mounted && generation == _generation) {
          setState(() => _failed = true);
        }
      } finally {
        _initializing = false;
      }
    });
  }

  Future<void> _capture() async {
    if (_busy || _camera?.value.isInitialized != true) return;
    setState(() => _busy = true);
    XFile? file;
    try {
      final generation = _generation;
      await _enqueue(() async {
        if (!mounted || !_foreground || generation != _generation) return;
        file = await _camera!.takePicture();
      });
      if (file == null) return;
      final Uint8List bytes = await file!.readAsBytes();
      if (bytes.length > 8000000) throw StateError('photo-too-large');
      if (mounted && generation == _generation) {
        setState(() => _preview = bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (file != null) {
        try {
          await File(file!.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android permission prompts can emit inactive/resumed during initialize.
    // They must not dispose the controller which is requesting permission.
    if (state == AppLifecycleState.inactive && _initializing) return;
    if (state == AppLifecycleState.resumed) {
      if (_foreground) return;
      _foreground = true;
      _initialize();
    } else {
      _foreground = false;
      _generation++;
      _enqueue(_closeCamera);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _foreground = false;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _enqueue(_closeCamera);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.vOpenCamera)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: _preview != null
                    ? Image.memory(_preview!, fit: BoxFit.contain)
                    : _failed
                    ? Center(child: Text(s.cameraUnavailable))
                    : _camera?.value.isInitialized != true
                    ? const Center(child: CircularProgressIndicator())
                    : CameraPreview(_camera!),
              ),
              const SizedBox(height: 16),
              if (_preview != null) ...[
                VolunteerAction(
                  s.usePhoto,
                  onPressed: () => Navigator.pop(context, _preview),
                ),
                const SizedBox(height: 12),
                VolunteerAction(
                  s.retakePhoto,
                  secondary: true,
                  onPressed: () => setState(() => _preview = null),
                ),
              ] else
                VolunteerAction(
                  _failed ? s.vTryAgain : s.capture,
                  onPressed: _busy
                      ? null
                      : _failed
                      ? () async {
                          if (mounted) {
                            setState(() => _failed = false);
                            _initialize();
                          }
                        }
                      : _capture,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VolunteerQrCapture extends StatefulWidget {
  const VolunteerQrCapture({super.key});
  @override
  State<VolunteerQrCapture> createState() => _VolunteerQrCaptureState();
}

class _VolunteerQrCaptureState extends State<VolunteerQrCapture>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_done) {
      _controller.start();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(stringsOf(context).vScanCode)),
    body: MobileScanner(
      controller: _controller,
      errorBuilder: (context, error) =>
          Center(child: Text(stringsOf(context).cameraUnavailable)),
      onDetect: (capture) {
        if (_done) return;
        for (final code in capture.barcodes) {
          final value = code.rawValue;
          if (value == null || value.isEmpty) continue;
          _done = true;
          _controller.stop();
          Navigator.pop(context, value);
          break;
        }
      },
    ),
  );
}
