import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Media type of a call.
enum CallMedia { audio, video }

/// High-level call state for the UI.
enum CallState { idle, ringing, connecting, active, ended }

class IncomingCall {
  IncomingCall({
    required this.callId,
    required this.conversationId,
    required this.media,
    required this.fromId,
    required this.fromName,
  });

  final String callId;
  final String conversationId;
  final CallMedia media;
  final String fromId;
  final String fromName;
}

/// WebRTC calling client. Signaling (invite/answer/ICE) is relayed through the
/// `/calls` socket.io gateway; audio/video media flows peer-to-peer and never
/// touches the server. Handles 1:1 audio/video calls and group audio rooms
/// (mesh: one peer connection per remote participant).
class CallClient {
  CallClient({required this.baseUrl, required this.iceServers});

  final String baseUrl;
  final List<Map<String, dynamic>> iceServers;

  io.Socket? _socket;
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, String> _participants = {}; // peerId -> display name (others)
  final Set<String> _mutedPeers = {}; // peers whose mic is off
  final Set<String> _speaking = {}; // ids currently speaking (incl. self)
  Timer? _speakingTimer;
  MediaStream? _localStream;

  String _selfId = '';
  String _callId = '';
  String _groupId = '';
  String _peerId = ''; // the remote user in a 1:1 call
  CallMedia _media = CallMedia.audio;
  CallState _state = CallState.idle;

  // UI callbacks
  void Function(IncomingCall call)? onIncomingCall;
  void Function(CallState state)? onStateChanged;
  void Function(String peerId, MediaStream stream)? onRemoteStream;
  void Function(String peerId)? onRemoteStreamRemoved;
  void Function(String reason)? onError;
  void Function()? onParticipantsChanged;

  CallState get state => _state;
  CallMedia get media => _media;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);
  bool get connected => _socket?.connected == true;

  /// Everyone in the group audio room, self first ('You'), with mic + speaking.
  List<({String id, String name, bool isSelf, bool muted, bool speaking})> get participants {
    final list = <({String id, String name, bool isSelf, bool muted, bool speaking})>[
      (id: _selfId, name: 'You', isSelf: true, muted: !_micEnabled, speaking: _speaking.contains(_selfId)),
    ];
    _participants.forEach((id, name) {
      if (id != _selfId) {
        list.add((id: id, name: name, isSelf: false, muted: _mutedPeers.contains(id), speaking: _speaking.contains(id)));
      }
    });
    return list;
  }

  Map<String, dynamic> get _rtcConfig => {
        'iceServers': iceServers.isNotEmpty
            ? iceServers
            : [
                {'urls': 'stun:stun.l.google.com:19302'}
              ],
        'sdpSemantics': 'unified-plan',
      };

  void connect(String token, String selfId) {
    disconnect();
    _selfId = selfId;
    final socket = io.io(
      '$baseUrl/calls',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    socket.on('call:incoming', (data) => _onIncoming(_map(data)));
    socket.on('call:accepted', (data) => _onAccepted(_map(data)));
    socket.on('call:declined', (_) => _onRemoteEnded('declined'));
    socket.on('call:cancelled', (_) => _onRemoteEnded('cancelled'));
    socket.on('call:ended', (_) => _onRemoteEnded('ended'));
    socket.on('peer:joined', (data) => _onPeerJoined(_map(data)));
    socket.on('peer:left', (data) => _onPeerLeft(_map(data)));
    socket.on('peer:mic', (data) => _onPeerMic(_map(data)));
    socket.on('mute:request', (_) => _onMuteRequest());
    socket.on('signal', (data) => _onSignal(_map(data)));
    socket.connect();
    _socket = socket;
  }

  // ---- 1:1 outgoing ----

  Future<void> invite({
    required String conversationId,
    required String calleeId,
    required CallMedia media,
  }) async {
    _media = media;
    _peerId = calleeId;
    _setState(CallState.ringing);
    await _ensureLocalStream(media);
    _socket?.emitWithAck('call:invite', {
      'conversationId': conversationId,
      'calleeId': calleeId,
      'media': media.name,
    }, ack: (res) {
      final map = _map(res);
      if (map['ok'] == true) {
        _callId = map['callId']?.toString() ?? '';
      } else {
        _fail(map['error']?.toString() ?? 'invite_failed');
      }
    });
  }

  // ---- 1:1 incoming ----

  Future<void> accept(IncomingCall call) async {
    _callId = call.callId;
    _peerId = call.fromId;
    _media = call.media;
    _setState(CallState.connecting);
    await _ensureLocalStream(call.media);
    // Peer connection is created when the caller's offer arrives.
    _socket?.emit('call:accept', {'callId': call.callId});
  }

  void decline(IncomingCall call) {
    _socket?.emit('call:decline', {'callId': call.callId});
    _setState(CallState.idle);
  }

  void cancel() {
    if (_callId.isNotEmpty) {
      _socket?.emit('call:cancel', {'callId': _callId, 'calleeId': _peerId});
    }
    _teardown('cancelled');
  }

  void hangUp() {
    if (_callId.isNotEmpty) _socket?.emit('call:end', {'callId': _callId});
    if (_groupId.isNotEmpty) _socket?.emit('room:leave', {'groupId': _groupId});
    _teardown('ended');
  }

  // ---- Group audio room ----

  Future<void> joinGroupAudio(String groupId) async {
    _media = CallMedia.audio;
    _groupId = groupId;
    _setState(CallState.connecting);
    await _ensureLocalStream(CallMedia.audio);
    _socket?.emitWithAck('room:join', {'groupId': groupId}, ack: (res) async {
      final map = _map(res);
      if (map['ok'] != true) {
        _fail(map['error']?.toString() ?? 'group_access_denied');
        return;
      }
      // Seed the participant list with peers already in the room.
      for (final raw in (map['peers'] as List? ?? const [])) {
        final p = _map(raw);
        final id = p['id']?.toString() ?? p['peerId']?.toString() ?? '';
        if (id.isNotEmpty && id != _selfId) {
          _participants[id] = p['fullName']?.toString() ?? p['name']?.toString() ?? 'Member';
        }
      }
      onParticipantsChanged?.call();
      _setState(CallState.active);
      _startSpeakingMonitor();
      // We wait for existing peers to send us offers (they get peer:joined).
    });
  }

  void leaveGroup() {
    if (_groupId.isNotEmpty) _socket?.emit('room:leave', {'groupId': _groupId});
    _teardown('ended');
  }

  // ---- Controls ----

  bool _micEnabled = true;
  bool get micEnabled => _micEnabled;
  void toggleMic() {
    _micEnabled = !_micEnabled;
    for (final track in _localStream?.getAudioTracks() ?? const []) {
      track.enabled = _micEnabled;
    }
    if (_groupId.isNotEmpty) {
      _socket?.emit('room:mic', {'groupId': _groupId, 'enabled': _micEnabled});
    }
    onParticipantsChanged?.call();
  }

  /// Room moderators mute a participant; the server relays to that peer.
  void muteParticipant(String peerId) {
    if (_groupId.isEmpty || peerId.isEmpty) return;
    _socket?.emit('room:mute', {'groupId': _groupId, 'targetId': peerId});
  }

  void _onMuteRequest() {
    if (_groupId.isNotEmpty && _micEnabled) toggleMic();
  }

  void _onPeerMic(Map<String, dynamic> data) {
    final peerId = data['peerId']?.toString() ?? '';
    if (peerId.isEmpty) return;
    if (data['enabled'] == true) {
      _mutedPeers.remove(peerId);
    } else {
      _mutedPeers.add(peerId);
    }
    onParticipantsChanged?.call();
  }

  // ---- Speaking (voice activity) detection via WebRTC stats ----

  void _startSpeakingMonitor() {
    _speakingTimer?.cancel();
    _speakingTimer = Timer.periodic(const Duration(milliseconds: 600), (_) => _pollSpeaking());
  }

  Future<void> _pollSpeaking() async {
    if (_peers.isEmpty) {
      if (_speaking.isNotEmpty) {
        _speaking.clear();
        onParticipantsChanged?.call();
      }
      return;
    }
    const threshold = 0.02;
    final speaking = <String>{};
    for (final entry in _peers.entries) {
      List<StatsReport> reports;
      try {
        reports = await entry.value.getStats();
      } catch (_) {
        continue;
      }
      for (final report in reports) {
        final values = report.values;
        final raw = values['audioLevel'];
        if (raw is! num) continue;
        final level = raw.toDouble();
        final kind = (values['kind'] ?? values['mediaType'])?.toString();
        if (kind != null && kind != 'audio') continue;
        final type = report.type;
        if (type.contains('inbound') || type == 'ssrc') {
          if (level > threshold) speaking.add(entry.key);
        } else if (type.contains('media-source') || type.contains('outbound')) {
          if (level > threshold && _micEnabled) speaking.add(_selfId);
        }
      }
    }
    if (!_sameIds(speaking, _speaking)) {
      _speaking
        ..clear()
        ..addAll(speaking);
      onParticipantsChanged?.call();
    }
  }

  bool _sameIds(Set<String> a, Set<String> b) => a.length == b.length && a.every(b.contains);

  bool _cameraEnabled = true;
  bool get cameraEnabled => _cameraEnabled;
  void toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    for (final track in _localStream?.getVideoTracks() ?? const []) {
      track.enabled = _cameraEnabled;
    }
  }

  Future<void> switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) await Helper.switchCamera(track);
  }

  // ---- Signaling handlers ----

  void _onIncoming(Map<String, dynamic> data) {
    final from = _map(data['from']);
    onIncomingCall?.call(IncomingCall(
      callId: data['callId']?.toString() ?? '',
      conversationId: data['conversationId']?.toString() ?? '',
      media: data['media'] == 'video' ? CallMedia.video : CallMedia.audio,
      fromId: from['id']?.toString() ?? '',
      fromName: from['fullName']?.toString() ?? 'Caller',
    ));
  }

  Future<void> _onAccepted(Map<String, dynamic> data) async {
    // Callee accepted; as the caller we initiate the offer.
    _setState(CallState.connecting);
    final pc = await _createPeer(_peerId, callId: _callId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sendSignal(to: _peerId, kind: 'offer', data: {'sdp': offer.sdp, 'type': offer.type}, callId: _callId);
  }

  Future<void> _onSignal(Map<String, dynamic> data) async {
    final from = data['from']?.toString() ?? '';
    final kind = data['kind']?.toString() ?? '';
    final callId = data['callId']?.toString() ?? '';
    final groupId = data['groupId']?.toString() ?? '';
    if (from.isEmpty) return;
    final payload = _map(data['data']);

    if (kind == 'offer') {
      if (callId.isNotEmpty) _callId = callId;
      final pc = await _createPeer(from, callId: callId, groupId: groupId);
      await pc.setRemoteDescription(RTCSessionDescription(payload['sdp']?.toString(), payload['type']?.toString()));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignal(to: from, kind: 'answer', data: {'sdp': answer.sdp, 'type': answer.type}, callId: callId, groupId: groupId);
    } else if (kind == 'answer') {
      final pc = _peers[from];
      await pc?.setRemoteDescription(RTCSessionDescription(payload['sdp']?.toString(), payload['type']?.toString()));
    } else if (kind == 'ice') {
      final pc = _peers[from];
      if (pc != null && payload['candidate'] != null) {
        await pc.addCandidate(RTCIceCandidate(
          payload['candidate']?.toString(),
          payload['sdpMid']?.toString(),
          (payload['sdpMLineIndex'] as num?)?.toInt(),
        ));
      }
    }
  }

  Future<void> _onPeerJoined(Map<String, dynamic> data) async {
    final peerId = data['peerId']?.toString() ?? '';
    if (peerId.isEmpty || peerId == _selfId) return;
    final user = _map(data['user']);
    _participants[peerId] = user['fullName']?.toString() ?? user['name']?.toString() ?? 'Member';
    onParticipantsChanged?.call();
    // Existing member initiates the offer toward the newcomer.
    final pc = await _createPeer(peerId, groupId: _groupId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    _sendSignal(to: peerId, kind: 'offer', data: {'sdp': offer.sdp, 'type': offer.type}, groupId: _groupId);
  }

  void _onPeerLeft(Map<String, dynamic> data) {
    final peerId = data['peerId']?.toString() ?? '';
    _participants.remove(peerId);
    onParticipantsChanged?.call();
    _closePeer(peerId);
  }

  void _onRemoteEnded(String reason) {
    if (_state == CallState.idle) return;
    _teardown(reason);
  }

  // ---- Peer connection lifecycle ----

  Future<RTCPeerConnection> _createPeer(String peerId, {String callId = '', String groupId = ''}) async {
    final existing = _peers[peerId];
    if (existing != null) return existing;
    final pc = await createPeerConnection(_rtcConfig);

    for (final track in _localStream?.getTracks() ?? const []) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _sendSignal(to: peerId, kind: 'ice', callId: callId.isNotEmpty ? callId : _callId, groupId: groupId, data: {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[peerId] = event.streams.first;
        onRemoteStream?.call(peerId, event.streams.first);
        if (_state != CallState.active) _setState(CallState.active);
      }
    };
    pc.onConnectionState = (pcState) {
      if (pcState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          pcState == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _closePeer(peerId);
      }
    };

    _peers[peerId] = pc;
    return pc;
  }

  void _closePeer(String peerId) {
    _peers.remove(peerId)?.close();
    _remoteStreams.remove(peerId);
    onRemoteStreamRemoved?.call(peerId);
    if (_peers.isEmpty && _groupId.isEmpty) _teardown('ended');
  }

  Future<void> _ensureLocalStream(CallMedia media) async {
    if (_localStream != null) return;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': media == CallMedia.video
          ? {'facingMode': 'user', 'width': 640, 'height': 480, 'frameRate': 24}
          : false,
    });
  }

  void _sendSignal({
    required String to,
    required String kind,
    required Map<String, dynamic> data,
    String callId = '',
    String groupId = '',
  }) {
    _socket?.emit('signal', {
      'to': to,
      'kind': kind,
      'data': data,
      if (callId.isNotEmpty) 'callId': callId,
      if (groupId.isNotEmpty) 'groupId': groupId,
    });
  }

  void _setState(CallState state) {
    _state = state;
    onStateChanged?.call(state);
  }

  void _fail(String reason) {
    onError?.call(reason);
    _teardown(reason);
  }

  void _teardown(String reason) {
    for (final pc in _peers.values) {
      pc.close();
    }
    _speakingTimer?.cancel();
    _speakingTimer = null;
    _peers.clear();
    _remoteStreams.clear();
    _participants.clear();
    _mutedPeers.clear();
    _speaking.clear();
    onParticipantsChanged?.call();
    for (final track in _localStream?.getTracks() ?? const []) {
      track.stop();
    }
    _localStream?.dispose();
    _localStream = null;
    _callId = '';
    _groupId = '';
    _peerId = '';
    _micEnabled = true;
    _cameraEnabled = true;
    if (_state != CallState.ended) _setState(CallState.ended);
    _setState(CallState.idle);
  }

  void disconnect() {
    _teardown('ended');
    final socket = _socket;
    if (socket != null) {
      socket
        ..clearListeners()
        ..disconnect()
        ..dispose();
      _socket = null;
    }
  }

  Map<String, dynamic> _map(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
