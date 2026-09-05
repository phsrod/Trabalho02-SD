import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera_service.dart';
import '../services/socket_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraService _cameraService = CameraService();
  final SocketService _socketService = SocketService();

  final TextEditingController _hostController = TextEditingController(
    text: '192.168.0.100',
  );

  final TextEditingController _portController = TextEditingController(
    text: '5000',
  );

  XFile? _capturedImage;
  Uint8List? _processedImageBytes;

  bool _isInitializing = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao inicializar a câmera: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty) {
      _showMessage('Informe o IP do servidor.');
      return;
    }

    if (port == null || port < 1 || port > 65535) {
      _showMessage('Informe uma porta válida.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Captura a imagem.
      final image = await _cameraService.takePicture();

      // Prepara a imagem para transmissão.
      final processedBytes = await _cameraService.prepareImageForSending(image);

      if (!mounted) return;

      setState(() {
        _capturedImage = image;
        _processedImageBytes = processedBytes;
      });

      // Envia a imagem para o servidor.
      final result = await _socketService.sendImage(
        host: host,
        port: port,
        imageBytes: processedBytes,
      );

      if (!mounted) return;

      _showMessage(
        result.objects.isEmpty
            ? 'Nenhum objeto detectado.'
            : 'Objetos detectados: ${result.objects.join(', ')}',
      );
    } on SocketException catch (error) {
      if (!mounted) return;

      _showMessage('Não foi possível conectar ao servidor: $error');
    } catch (error) {
      if (!mounted) return;

      _showMessage('Erro ao enviar imagem: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Foto via Botão'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : controller == null || !controller.value.isInitialized
                      ? const Center(
                          child: Text(
                            'Não foi possível inicializar a câmera.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : CameraPreview(controller),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _hostController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'IP do servidor',
                        hintText: 'Ex.: 192.168.0.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Porta',
                        hintText: '5000',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.settings_ethernet),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_capturedImage != null) ...[
                SizedBox(
                  height: 100,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (_processedImageBytes != null)
                Text(
                  'Imagem preparada: '
                  '${(_processedImageBytes!.length / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isInitializing || _isProcessing
                      ? null
                      : _takePicture,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      _isProcessing ? 'Enviando...' : 'Tirar e Analisar',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Servidor: '
                '${_hostController.text}:${_portController.text}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
