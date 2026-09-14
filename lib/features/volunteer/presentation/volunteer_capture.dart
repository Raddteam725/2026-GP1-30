import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'volunteer_components.dart';

/// In-app camera only. Capture returns bytes directly; no gallery/review step.
class VolunteerCapture extends StatefulWidget {
  const VolunteerCapture({super.key});
  @override
  State<VolunteerCapture> createState() => _VolunteerCaptureState();
}

class _VolunteerCaptureState extends State<VolunteerCapture>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _busy = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
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
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _failed = false);
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _capture() async {
    if (_busy || _camera?.value.isInitialized != true) return;
    setState(() => _busy = true);
    XFile? file;
    try {
      file = await _camera!.takePicture();
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.length > 8000000) throw StateError('photo-too-large');
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (file != null) {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _generation++;
      final camera = _camera;
      _camera = null;
      camera?.dispose();
    } else if (_camera == null) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
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
                child: _failed
                    ? Center(child: Text(s.cameraUnavailable))
                    : _camera?.value.isInitialized != true
                    ? const Center(child: CircularProgressIndicator())
                    : CameraPreview(_camera!),
              ),
              const SizedBox(height: 16),
              VolunteerAction(
                _failed ? s.vTryAgain : s.capture,
                onPressed: _busy
                    ? null
                    : _failed
                    ? () async {
                        await _camera?.dispose();
                        _camera = null;
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
