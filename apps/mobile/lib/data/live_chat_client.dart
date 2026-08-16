import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class LiveChatClient {
  LiveChatClient({required this.baseUrl});

  final String baseUrl;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typing =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _reads =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _edits =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deletes =
      StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? _socket;
  // Conversations we should be in — replayed on every (re)connect so a network
  // blip or an auth race can never leave the client silently unsubscribed.
  final Set<String> _subscriptions = {};

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get reads => _reads.stream;
  Stream<Map<String, dynamic>> get edits => _edits.stream;
  Stream<Map<String, dynamic>> get deletes => _deletes.stream;
  bool get connected => _socket?.connected == true;

  void connect(String token) {
    disconnect();
    final socket = io.io(
      '$baseUrl/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    socket.on('connect', (_) {
      for (final conversationId in _subscriptions) {
        socket.emit(
            'conversation:subscribe', {'conversationId': conversationId});
      }
    });
    socket.on('message:new', (data) => _add(_messages, data));
    socket.on('typing', (data) => _add(_typing, data));
    socket.on('message:read', (data) => _add(_reads, data));
    socket.on('message:unread', (data) => _add(_reads, data));
    socket.on('message:edited', (data) => _add(_edits, data));
    socket.on('message:deleted', (data) => _add(_deletes, data));
    socket.connect();
    _socket = socket;
  }

  void subscribe(String conversationId) {
    _subscriptions.add(conversationId);
    if (connected) {
      _socket?.emit(
          'conversation:subscribe', {'conversationId': conversationId});
    }
  }

  void unsubscribe(String conversationId) {
    _subscriptions.remove(conversationId);
    _socket
        ?.emit('conversation:unsubscribe', {'conversationId': conversationId});
  }

  void sendMessage({
    required String conversationId,
    required String body,
    String attachmentUrl = '',
    String attachmentType = '',
    String? tempId,
    Map<String, dynamic>? encryption,
  }) {
    _socket?.emit('message:send', {
      'conversationId': conversationId,
      'body': body,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      if (tempId != null && tempId.isNotEmpty) 'tempId': tempId,
      ...?encryption,
    });
  }

  void markRead(String conversationId, {String? messageId}) {
    _socket?.emit('message:read', {
      'conversationId': conversationId,
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
    });
  }

  void markUnread(String conversationId, {String? messageId}) {
    _socket?.emit('message:unread', {
      'conversationId': conversationId,
      if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
    });
  }

  void editMessage(String conversationId, String messageId, String body) {
    _socket?.emit('message:edit', {
      'conversationId': conversationId,
      'messageId': messageId,
      'body': body,
    });
  }

  void deleteMessage(String conversationId, String messageId) {
    _socket?.emit('message:delete', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  void setTyping(String conversationId, bool typing) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'typing': typing,
    });
  }

  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    socket
      ..clearListeners()
      ..disconnect()
      ..dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messages.close();
    _typing.close();
    _reads.close();
    _edits.close();
    _deletes.close();
  }

  void _add(
    StreamController<Map<String, dynamic>> controller,
    dynamic data,
  ) {
    if (data is Map<String, dynamic>) {
      controller.add(data);
    } else if (data is Map) {
      controller.add(Map<String, dynamic>.from(data));
    }
  }
}
