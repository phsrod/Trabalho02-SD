import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/camera_service.dart';
import '../services/socket_service.dart';

/// Chaves usadas para persistir a configuração do servidor.
const _kPrefHost = 'server_host';
const _kPrefPort = 'server_port';

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

  final GlobalKey _previewKey = GlobalKey();

  XFile? _capturedImage;
  Uint8List? _processedImageBytes;

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isSwitchingCamera = false;
  bool _isSavingSettings = false;
  bool _showFlash = false;

  String? _hostError;
  String? _portError;

  /// Rótulo/status da última análise, exibido no painel de resultado.
  String? _resultTitle;
  String? _resultSubtitle;

  /// Objetos retornados pela última análise.
  List<String> _detectedObjects = const [];

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedHost = prefs.getString(_kPrefHost);
      final savedPort = prefs.getString(_kPrefPort);

      if (!mounted) return;

      setState(() {
        if (savedHost != null && savedHost.isNotEmpty) {
          _hostController.text = savedHost;
        }
        if (savedPort != null && savedPort.isNotEmpty) {
          _portController.text = savedPort;
        }
      });
    } catch (_) {
      // Preferências são opcionais: segue com os valores padrão.
    }
  }

  Future<void> _saveSettings() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();

    if (!_validate(host, port)) {
      return;
    }

    setState(() {
      _isSavingSettings = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_kPrefHost, host);
      await prefs.setString(_kPrefPort, port);

      if (!mounted) return;

      Navigator.of(context).pop();
      _showMessage(
        'Servidor salvo: $host:$port',
        icon: Icons.check_circle,
        color: Colors.greenAccent,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Não foi possível salvar: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSettings = false;
        });
      }
    }
  }

  bool _validate(String host, String port) {
    final portNumber = int.tryParse(port);

    setState(() {
      _hostError = host.isEmpty ? 'Informe o IP do servidor.' : null;
      _portError =
          (portNumber == null || portNumber < 1 || portNumber > 65535)
              ? 'Porta inválida.'
              : null;
    });

    return _hostError == null && _portError == null;
  }

  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
    } catch (error) {
      if (!mounted) return;

      _showMessage('Erro ao inicializar a câmera: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_isSwitchingCamera ||
        _isProcessing ||
        !_cameraService.canSwitchCamera) {
      return;
    }

    setState(() {
      _isSwitchingCamera = true;
    });

    HapticFeedback.selectionClick();

    try {
      await _cameraService.switchCamera();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Erro ao trocar de câmera: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _takePicture() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final portNumber = int.tryParse(port);

    if (!_validate(host, port)) {
      _showMessage('Verifique a conexão com o servidor.', isError: true);
      _openServerSheet();
      return;
    }

    setState(() {
      _isProcessing = true;
      _resultTitle = null;
      _resultSubtitle = null;
      _detectedObjects = const [];
    });

    HapticFeedback.mediumImpact();

    try {
      // Captura a imagem.
      final image = await _cameraService.takePicture();

      // Prepara a imagem para transmissão.
      final processedBytes =
          await _cameraService.prepareImageForSending(image);

      if (!mounted) return;

      setState(() {
        _capturedImage = image;
        _processedImageBytes = processedBytes;
      });

      // Envia a imagem para o servidor.
      final result = await _socketService.sendImage(
        host: host,
        port: portNumber!,
        imageBytes: processedBytes,
      );

      if (!mounted) return;

      setState(() {
        _detectedObjects = result.objects;
        _resultTitle = result.objects.isEmpty
            ? 'Nenhum objeto detectado'
            : result.objects.length == 1
                ? '1 objeto detectado'
                : '${result.objects.length} objetos detectados';
        _resultSubtitle = result.objects.isEmpty
            ? 'Tire outra foto ou aproxime-se do objeto.'
            : TimeOfDay.now().format(context);
      });
    } on SocketException {
      if (!mounted) return;

      _showMessage(
        'Não foi possível conectar. Verifique o IP, a porta e se o '
        'servidor está rodando.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Erro ao enviar imagem: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
    IconData? icon,
    Color? color,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.info_outline),
              color: color ??
                  (isError ? Colors.redAccent : Colors.greenAccent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFF3A1518)
            : const Color(0xFF12312A),
      ),
    );
  }

  /// Abre o painel de configurações do servidor (bottom sheet).
  Future<void> _openServerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Conexão do servidor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'IP do servidor',
                  hintText: 'Ex.: 192.168.0.100',
                  prefixIcon: const Icon(Icons.computer),
                  errorText: _hostError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Porta',
                  hintText: '5000',
                  prefixIcon: const Icon(Icons.settings_ethernet),
                  errorText: _portError,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSavingSettings ? null : _saveSettings,
                icon: _isSavingSettings
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Salvar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Constrói o chip de um objeto detectado, com cor fixa por nome.
  Widget _buildObjectChip(String label) {
    const palette = [
      Colors.tealAccent,
      Colors.lightBlueAccent,
      Colors.amberAccent,
      Colors.pinkAccent,
      Colors.limeAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
    ];

    final color = palette[label.hashCode.abs() % palette.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraService.controller;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detecção de Objetos'),
        actions: [
          IconButton(
            tooltip: 'Conexão do servidor',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _openServerSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    key: _previewKey,
                    children: [
                      // Prévia da câmera.
                      if (_isInitializing)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 12),
                              Text(
                                'Iniciando câmera...',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (controller == null ||
                          !controller.value.isInitialized)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.no_photography_outlined,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Não foi possível inicializar a câmera.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        CameraPreview(controller),

                      // Overlay durante o processamento.
                      if (_isProcessing)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  const Text('Analisando imagem...'),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Flash do obturador.
                      AnimatedOpacity(
                        opacity: _showFlash ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(color: Colors.white),
                      ),

                      // Botão de alternar câmera (canto superior direito).
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _CameraButton(
                          icon: Icons.cameraswitch_outlined,
                          tooltip: 'Alternar câmera',
                          onPressed: (_isInitializing ||
                                  _isProcessing ||
                                  _isSwitchingCamera)
                              ? null
                              : _toggleCamera,
                          child: _isSwitchingCamera
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botão obturador central, estilo app de câmera.
              _ShutterButton(
                onPressed:
                    (_isInitializing || _isProcessing || _isSwitchingCamera)
                    ? null
                    : () async {
                        setState(() {
                          _showFlash = true;
                        });

                        await Future<void>.delayed(
                          const Duration(milliseconds: 120),
                        );

                        if (mounted) {
                          setState(() {
                            _showFlash = false;
                          });
                        }

                        await _takePicture();
                      },
                isBusy: _isProcessing,
              ),

              const SizedBox(height: 16),

              // Painel de resultado da análise.
              if (_resultTitle != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _resultTitle!.startsWith('Nenhum')
                                ? Icons.search_off
                                : Icons.check_circle,
                            size: 20,
                            color: _resultTitle!.startsWith('Nenhum')
                                ? colorScheme.onSurfaceVariant
                                : Colors.greenAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _resultTitle!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (_processedImageBytes != null)
                            Text(
                              '${(_processedImageBytes!.length / 1024).toStringAsFixed(0)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (_resultSubtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _resultSubtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _detectedObjects
                            .map((object) => _buildObjectChip(object))
                            .toList(),
                      ),
                    ],
                  ),
                ),

              // Miniatura da foto capturada.
              if (_capturedImage != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_capturedImage!.path),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Última foto capturada',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Status da conexão atual.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: (_hostError == null && _portError == null)
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Servidor: ${_hostController.text.trim()}:${_portController.text.trim()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão redondo reutilizável usado sobre a prévia da câmera.
class _CameraButton extends StatelessWidget {
  const _CameraButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.child,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Conteúdo alternativo (ex.: spinner) no lugar do ícone.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: child ?? Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Botão obturador grande, estilo app de câmera.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed, required this.isBusy});

  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Semantics(
      button: true,
      label: 'Tirar foto e analisar',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disabled ? Colors.white24 : Colors.white,
            border: Border.all(
              color: disabled ? Colors.white10 : Colors.tealAccent,
              width: 4,
            ),
          ),
          child: Center(
            child: isBusy
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    Icons.camera_alt,
                    size: 30,
                    color: disabled ? Colors.white24 : Colors.black87,
                  ),
          ),
        ),
      ),
    );
  }
}
