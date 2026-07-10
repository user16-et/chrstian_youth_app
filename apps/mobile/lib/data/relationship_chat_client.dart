import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Realtime socket client for the courtship (matched-couple) chat: instant
/// message delivery, typing indicators and read receipts.
class RelationshipChatClient {
  RelationshipChatClient({required this.baseUrl});

  final String baseUrl;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _reads = StreamController<Map<String, dynamic>>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  io.Socket? _socket;
  String? _pendingJoin; // room to join once the server confirms auth ('ready')
  bool _ready = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get reads => _reads.stream;
  Stream<bool> get connectionState => _connection.stream;
  bool get connected => _socket?.connected == true && _ready;

  void connect(String token) {
    disconnect();
    final socket = io.io(
      '$baseUrl/relationship-chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    // 'ready' fires after the server authenticates the socket. Only then is it
    // safe to join a room / send.
    socket.on('ready', (_) {
      _ready = true;
      final pending = _pendingJoin;
      if (pending != null) {
        socket.emit('join', {'connectionId': pending});
        socket.emit('read', {'connectionId': pending});
      }
      _connection.add(true);
    });
    socket.onDisconnect((_) {
      _ready = false;
      _connection.add(false);
    });
    socket.on('message:new', (data) => _add(_messages, data));
    socket.on('typing', (data) => _add(_typing, data));
    socket.on('read', (data) => _add(_reads, data));
    socket.connect();
    _socket = socket;
  }

  void join(String connectionId) {
    _pendingJoin = connectionId;
    if (_ready) _socket?.emit('join', {'connectionId': connectionId});
  }

  void leave(String connectionId) {
    if (_pendingJoin == connectionId) _pendingJoin = null;
    _socket?.emit('leave', {'connectionId': connectionId});
  }

  void send({required String connectionId, required String body, String verseReference = '', String? tempId}) {
    _socket?.emit('message', {
      'connectionId': connectionId,
      'body': body,
      'verseReference': verseReference,
      if (tempId != null && tempId.isNotEmpty) 'tempId': tempId,
    });
  }

  void setTyping(String connectionId, bool typing) =>
      _socket?.emit('typing', {'connectionId': connectionId, 'typing': typing});

  void markRead(String connectionId) => _socket?.emit('read', {'connectionId': connectionId});

  void _add(StreamController<Map<String, dynamic>> controller, dynamic data) {
    if (data is Map) controller.add(data.cast<String, dynamic>());
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messages.close();
    _typing.close();
    _reads.close();
    _connection.close();
  }
}
