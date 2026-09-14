import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/primary_button.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _busy = false;
  String? _error;
  Uint8List? _preview;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    setState(() => _error = null);
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw CameraException('Unavailable', '');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } on CameraException catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () =>
              _error = e.code.contains('Access') ? 'permission' : 'unavailable',
        );
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'unavailable');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive &&
        _controller?.value.isInitialized == true) {
      _generation++;
      final c = _controller;
      _controller = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initialize();
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final image = await controller.takePicture().timeout(
        const Duration(seconds: 20),
      );
      final bytes = await image.readAsBytes();
      await File(image.path).delete(); // Only this capture's app-cache file.
      if (bytes.length > 8000000) {
        if (mounted) setState(() => _error = 'size');
        return;
      }
      if (mounted) setState(() => _preview = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'unavailable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final controller = _controller;
    final previewHeight = (MediaQuery.sizeOf(context).height * .52).clamp(
      240.0,
      480.0,
    );
    return FeaturePage(
      title: s.takePhoto,
      subtitle: s.cameraGuide,
      children: [
        if (_preview != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: previewHeight,
              child: Image.memory(_preview!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: s.usePhoto,
            onPressed: () => Navigator.pop(context, _preview),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _preview = null),
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(s.retakePhoto),
          ),
        ] else if (_error != null)
          ErrorNotice(
            message: _error == 'permission'
                ? s.cameraDenied
                : _error == 'size'
                ? s.photoTooLarge
                : s.cameraUnavailable,
            onRetry: () async {
              await _controller?.dispose();
              _controller = null;
              if (mounted) _initialize();
            },
          )
        else if (controller == null || !controller.value.isInitialized)
          const Center(child: CircularProgressIndicator())
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: previewHeight,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1 / controller.value.aspectRatio,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: s.capture,
            onPressed: _capture,
            isLoading: _busy,
          ),
        ],
      ],
    );
  }
}
