import 'package:camera/camera.dart';

class CameraService{
    CameraController? _controller;
    CameraController? get controller => _controller;

    Future<void> initializeCamera() async {
        final cameras = await availableCameras();

        if (cameras.isEmpty) {
            throw Exception('Nenhuma câmera disponível');            
        }

        final camera = cameras.first;
        _controller = CameraController(camera, ResolutionPreset.high, enableaAudio: false);

        await _controller!.initialize();
    }

    Future<XFile> takePicture() async {
        if(_controller == null || !_controller!.value.isInitialized){
            throw Exception('Câmera não inicializada');
        }
        return _controller!.takePicture();
    }

    Future<void> dispose() async {
        await _controller?.dispose();
        _controller = null;
    }
}