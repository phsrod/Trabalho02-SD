import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/detection_result.dart';

class SocketService {
  Future<DetectionResult> sendImage({
    required String host,
    required int port,
    required List<int> imageBytes,
  }) async {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 10),
    );

    try {
      // Envia o tamanho da imagem em 4 bytes, big-endian.
      final sizeBytes = ByteData(4)
        ..setUint32(0, imageBytes.length, Endian.big);

      socket.add(sizeBytes.buffer.asUint8List());
      socket.add(imageBytes);

      await socket.flush();

      // Recebe primeiro os 4 bytes com o tamanho da resposta.
      final responseSizeBytes = await _readExactly(socket, 4);

      final responseSize = ByteData.sublistView(responseSizeBytes)
          .getUint32(0, Endian.big);

      // Recebe exatamente o JSON enviado pelo servidor.
      final responseBytes = await _readExactly(socket, responseSize);

      final responseJson = jsonDecode(utf8.decode(responseBytes));

      return DetectionResult.fromJson(responseJson);
    } finally {
      await socket.close();
    }
  }

  Future<Uint8List> _readExactly(Socket socket, int length) async {
    final buffer = <int>[];

    await for (final chunk in socket) {
      buffer.addAll(chunk);

      if (buffer.length >= length) {
        return Uint8List.fromList(buffer.sublist(0, length));
      }
    }

    throw const SocketException(
      'Conexão encerrada antes de receber todos os dados.',
    );
  }
}
