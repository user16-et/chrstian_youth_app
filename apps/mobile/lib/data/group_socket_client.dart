import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Realtime socket for a group/channel wall: live posts, deletes, pins and
/// typing. Mirrors the courtship chat client's 'ready'-then-join handshake.
class GroupSocketClient {
  GroupSocketClient({required this.baseUrl});

  final String baseUrl;

  final _newPosts = StreamController<Map<String, dynamic>>.broadcast();
  final _removed = StreamController<Map<String, dynamic>>.broadcast();
  final _wallChanged = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _newPolls = StreamController<Map<String, dynamic>>.broadcast();
  final _pollUpdates = StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? _socket;
  String? _pendingJoin;
  bool _ready = false;

  Stream<Map<String, dynamic>> get newPosts => _newPosts.stream;
  Stream<Map<String, dynamic>> get removedPosts => _removed.stream;
  Stream<Map<String, dynamic>> get wallChanged => _wallChanged.stream;
  Stream<Map<String, dynamic>> get typing => _typing.stream;
  Stream<Map<String, dynamic>> get newPolls => _newPolls.stream;
  Stream<Map<String, dynamic>> get pollUpdates => _pollUpdates.stream;
  bool get connected => _socket?.connected == true && _ready;

  void connect(String token) {
    disconnect();
    final socket = io.io(
      '$baseUrl/groups',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    socket.on('ready', (_) {
      _ready = true;
      final pending = _pendingJoin;
      if (pending != null) socket.emit('join', {'groupId': pending});
    });
    socket.onDisconnect((_) => _ready = false);
    socket.on('post:new', (d) => _add(_newPosts, d));
    socket.on('post:removed', (d) => _add(_removed, d));
    socket.on('wall:changed', (d) => _add(_wallChanged, d));
    socket.on('typing', (d) => _add(_typing, d));
    socket.on('poll:new', (d) => _add(_newPolls, d));
    socket.on('poll:update', (d) => _add(_pollUpdates, d));
    socket.connect();
    _socket = socket;
  }

  void join(String groupId) {
    _pendingJoin = groupId;
    if (_ready) _socket?.emit('join', {'groupId': groupId});
  }

  void leave(String groupId) {
    if (_pendingJoin == groupId) _pendingJoin = null;
    _socket?.emit('leave', {'groupId': groupId});
  }

  void post(String groupId, {required String body, String mediaUrl = ''}) =>
      _socket?.emit('post', {'groupId': groupId, 'body': body, 'mediaUrl': mediaUrl});

  void deletePost(String groupId, String postId) => _socket?.emit('post:delete', {'groupId': groupId, 'postId': postId});

  void pinPost(String groupId, String postId, bool pinned) =>
      _socket?.emit('post:pin', {'groupId': groupId, 'postId': postId, 'pinned': pinned});

  void setTyping(String groupId, bool typing) => _socket?.emit('typing', {'groupId': groupId, 'typing': typing});

  void createPoll(String groupId, {required String question, required List<String> options}) =>
      _socket?.emit('poll:create', {'groupId': groupId, 'question': question, 'options': options});

  void votePoll(String groupId, String pollId, int optionIndex) =>
      _socket?.emit('poll:vote', {'groupId': groupId, 'pollId': pollId, 'optionIndex': optionIndex});

  void closePoll(String groupId, String pollId, bool closed) =>
      _socket?.emit('poll:close', {'groupId': groupId, 'pollId': pollId, 'closed': closed});

  void _add(StreamController<Map<String, dynamic>> c, dynamic data) {
    if (data is Map) c.add(data.cast<String, dynamic>());
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _ready = false;
  }

  void dispose() {
    disconnect();
    _newPosts.close();
    _removed.close();
    _wallChanged.close();
    _typing.close();
    _newPolls.close();
    _pollUpdates.close();
  }
}
