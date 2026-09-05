import 'dart:async';
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

    final reader = _SocketReader(socket);

    try {
      final sizeBytes = ByteData(4)
        ..setUint32(0, imageBytes.length, Endian.big);

      socket.add(sizeBytes.buffer.asUint8List());
      socket.add(imageBytes);

      await socket.flush();

      // Recebe o tamanho da resposta.
      final responseSizeBytes = await reader.readExactly(4);

      final responseSize = ByteData.sublistView(responseSizeBytes)
          .getUint32(0, Endian.big);

      // Recebe exatamente o JSON.
      final responseBytes = await reader.readExactly(responseSize);

      final responseJson =
          jsonDecode(utf8.decode(responseBytes)) as Map<String, dynamic>;

      return DetectionResult.fromJson(responseJson);
    } finally {
      await reader.dispose();
      await socket.close();
    }
  }
}

class _SocketReader {
  _SocketReader(this._socket) {
    _subscription = _socket.listen(_onData, onError: _onError, onDone: _onDone);
  }

  final Socket _socket;

  late final StreamSubscription<List<int>> _subscription;

  final BytesBuilder _buffer = BytesBuilder(copy: false);

  final List<_PendingRead> _pendingReads = [];

  Object? _error;

  bool _done = false;

  Future<Uint8List> readExactly(int length) {
    if (length <= 0) {
      return Future.value(Uint8List(0));
    }

    if (_buffer.length >= length) {
      final data = _buffer.takeBytes();

      final result = Uint8List.fromList(data.sublist(0, length));

      final remaining = data.sublist(length);

      if (remaining.isNotEmpty) {
        _buffer.add(remaining);
      }

      return Future.value(result);
    }

    if (_error != null) {
      return Future.error(_error!);
    }

    if (_done) {
      return Future.error(
        const SocketException(
          'Conexão encerrada antes de receber todos os dados.',
        ),
      );
    }

    final completer = Completer<Uint8List>();

    _pendingReads.add(_PendingRead(length: length, completer: completer));

    return completer.future;
  }

  void _onData(List<int> data) {
    if (_error != null || _done) {
      return;
    }

    _buffer.add(data);

    _processPendingReads();
  }

  void _processPendingReads() {
    while (_pendingReads.isNotEmpty) {
      final pending = _pendingReads.first;

      if (_buffer.length < pending.length) {
        return;
      }

      final data = _buffer.takeBytes();

      final result = Uint8List.fromList(data.sublist(0, pending.length));

      final remaining = data.sublist(pending.length);

      if (remaining.isNotEmpty) {
        _buffer.add(remaining);
      }

      _pendingReads.removeAt(0);

      if (!pending.completer.isCompleted) {
        pending.completer.complete(result);
      }
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    _error = error;

    for (final pending in _pendingReads) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error, stackTrace);
      }
    }

    _pendingReads.clear();
  }

  void _onDone() {
    _done = true;

    if (_pendingReads.isEmpty) {
      return;
    }

    final error = const SocketException(
      'Conexão encerrada antes de receber todos os dados.',
    );

    for (final pending in _pendingReads) {
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }

    _pendingReads.clear();
  }

  Future<void> dispose() async {
    await _subscription.cancel();
  }
}

class _PendingRead {
  _PendingRead({required this.length, required this.completer});

  final int length;
  final Completer<Uint8List> completer;
}
