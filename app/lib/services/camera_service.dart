import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception('Nenhuma câmera disponível');
    }

    final camera = cameras.first;

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
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

    if (decodedImage.width > 1280) {
      processedImage = img.copyResize(decodedImage, width: 1280);
    }

    final jpegBytes = img.encodeJpg(processedImage, quality: 80);

    return Uint8List.fromList(jpegBytes);
  }

  Future<void> dispose() async {
    await _controller?.dispose();

    _controller = null;
  }
}
