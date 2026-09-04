import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/detection_result.dart';

class socketService {
    Future<DetectionResult> sendImage({required String host, required int port, required List<int> imageBytes,}) async {
        final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10),);
        try {
            // envia o tamanho da imagem em 4 bytes, big-endian
            final sizeBytes = ByteData(4)..setUint32(0, imageBytes.length, Endian.big);
            socket.add(sizeBytes.buffer.asUint8List());
            socket.add(imageBytes);
            await socket.flush();

            // recebe primeiro os 4 bytes com o tamanho da resposta
            final responseSizeBytes = await _reactExactly(socket, 4);
            final responseSize = ByteData.sublistView(responseSizeBytes,).getUint32(0, Endian.big);

            // recebe exatamente o JSON enviado pelo servidor
            final responseBytes = await _reactExactly(socket, responseSize);
            final responseJson = jsonDecode(utf8.decode(responseBytes),);
            
            return DetectionResult.fromJson(responseJson);
        } finally {
            await socket.close();
        }
    }

    Future<List<int>> _reactExactly(Socket socket, int length) async {
        final buffer = <int>[];
        await for (final chunk in socket){
            buffer.addAll(chunk);

            if(buffer.length >= length){
                return buffer.sublist(0, length);
            }
        }
        throw const SocketException('Conexão encerrada antes de receber todos os dados');
    }
}