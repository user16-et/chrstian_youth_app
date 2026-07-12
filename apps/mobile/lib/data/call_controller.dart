import 'package:flutter/material.dart';

import '../features/modules/call_screen.dart';
import 'api_client.dart';
import 'app_models.dart';
import 'call_client.dart';

/// Navigator key used to present incoming-call UI from anywhere in the app.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide calling controller. Keeps a single [CallClient] connected to the
/// `/calls` gateway while the user is signed in, receives incoming calls, and
/// launches the call screen. Exposed to the widget tree via [CallScope].
class CallController {
  CallController({required this.apiClient});

  final ApiClient apiClient;
  CallClient? _client;
  String _boundToken = '';
  bool _inCall = false;

  bool get ready => _client != null;

  /// Connects (or disconnects) the call socket to match the current session.
  Future<void> bind(AuthResult? session) async {
    final token = session?.token ?? '';
    if (token == _boundToken) return;
    _boundToken = token;
    _client?.disconnect();
    _client = null;
    if (session == null || token.isEmpty) return;

    List<Map<String, dynamic>> ice = const [];
    try {
      ice = await apiClient.fetchIceServers(token);
    } catch (_) {
      // A missing ICE config still allows connections via the built-in default.
    }
    if (_boundToken != token) return; // session changed while awaiting
    final client = CallClient(baseUrl: apiClient.baseUrl, iceServers: ice);
    client.onIncomingCall = _handleIncoming;
    client.connect(token, session.user.id);
    _client = client;
  }

  Future<void> startDirectCall({
    required String conversationId,
    required String calleeId,
    required CallMedia media,
    required String title,
  }) async {
    final client = _client;
    if (client == null || _inCall || calleeId.isEmpty || conversationId.isEmpty) return;
    await client.invite(conversationId: conversationId, calleeId: calleeId, media: media);
    _openCallScreen(title: title, isGroup: false);
  }

  Future<void> joinGroupAudio({required String groupId, required String title, bool canManageRoom = false}) async {
    final client = _client;
    if (client == null || _inCall || groupId.isEmpty) return;
    await client.joinGroupAudio(groupId);
    _openCallScreen(title: title, isGroup: true, canManageRoom: canManageRoom);
  }

  Future<void> _handleIncoming(IncomingCall call) async {
    final client = _client;
    final context = rootNavigatorKey.currentContext;
    if (client == null || context == null || _inCall) {
      _client?.decline(call);
      return;
    }
    final accepted = await showIncomingCallSheet(context, call);
    if (accepted) {
      await client.accept(call);
      _openCallScreen(title: call.fromName, isGroup: false);
    } else {
      client.decline(call);
    }
  }

  void _openCallScreen({required String title, required bool isGroup, bool canManageRoom = false}) {
    final client = _client;
    final navigator = rootNavigatorKey.currentState;
    if (client == null || navigator == null) return;
    _inCall = true;
    navigator
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CallScreen(client: client, title: title, isGroup: isGroup, canManageRoom: canManageRoom),
        ))
        .whenComplete(() => _inCall = false);
  }

  void dispose() {
    _client?.disconnect();
    _client = null;
    _boundToken = '';
  }
}

/// Makes the [CallController] available to descendants (including pushed routes
/// when placed in `MaterialApp.builder`).
class CallScope extends InheritedWidget {
  const CallScope({super.key, required this.controller, required super.child});

  final CallController controller;

  static CallController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CallScope>()?.controller;

  @override
  bool updateShouldNotify(CallScope oldWidget) => controller != oldWidget.controller;
}
