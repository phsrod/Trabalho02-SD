import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;

  List<CameraDescription> _cameras = [];

  int _currentIndex = 0;

  CameraController? get controller => _controller;

  /// Retorna a câmera atualmente em uso.
  CameraDescription? get currentCamera =>
      _cameras.isEmpty ? null : _cameras[_currentIndex];

  /// Retorna `true` quando a câmera ativa é a frontal.
  bool get isFrontCamera =>
      currentCamera?.lensDirection == CameraLensDirection.front;

  /// Retorna `true` quando existe mais de uma câmera para alternar.
  bool get canSwitchCamera => _cameras.length > 1;

  Future<void> initializeCamera() async {
    _cameras = await availableCameras();

    if (_cameras.isEmpty) {
      throw Exception('Nenhuma câmera disponível');
    }

    // Prefere a câmera traseira ao abrir o app.
    _currentIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    if (_currentIndex < 0) {
      _currentIndex = 0;
    }

    await _startController();
  }

  Future<void> _startController() async {
    final previousController = _controller;

    final controller = CameraController(
      _cameras[_currentIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    await controller.initialize();

    // Libera a câmera anterior somente depois que a nova está pronta,
    // para que a troca aconteça sem "tela preta".
    if (previousController != null) {
      await previousController.dispose();
    }
  }

  /// Alterna entre as câmeras disponíveis (frontal <-> traseira).
  Future<void> switchCamera() async {
    if (!canSwitchCamera || _controller == null) {
      return;
    }

    _currentIndex = (_currentIndex + 1) % _cameras.length;

    await _startController();
  }

  Future<XFile> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Câmera não inicializada');
    }

    return _controller!.takePicture();
  }

  Future<Uint8List> prepareImageForSending(XFile imageFile) async {
    final imageBytes = await imageFile.readAsBytes();

    final decodedImage = img.decodeImage(imageBytes);

    if (decodedImage == null) {
      throw Exception('Não foi possível processar a imagem');
    }

    img.Image processedImage = decodedImage;

    // Corrige a orientação da foto (essencial na câmera frontal).
    processedImage = img.bakeOrientation(processedImage);

    if (processedImage.width > 1280) {
      processedImage = img.copyResize(processedImage, width: 1280);
    }

    final jpegBytes = img.encodeJpg(processedImage, quality: 80);

    return Uint8List.fromList(jpegBytes);
  }

  Future<void> dispose() async {
    await _controller?.dispose();

    _controller = null;
  }
}
