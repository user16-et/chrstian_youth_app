import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/call_client.dart';

/// Full-screen call UI for a 1:1 audio/video call or a group audio room.
/// Assumes [client] has already started the call (invite/accept/joinGroupAudio).
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.client,
    required this.title,
    required this.isGroup,
    this.canManageRoom = false,
  });

  final CallClient client;
  final String title;
  final bool isGroup;
  final bool canManageRoom;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  bool _rendererReady = false;

  @override
  void initState() {
    super.initState();
    final client = widget.client;
    client.onStateChanged = _onStateChanged;
    client.onRemoteStream = _attachRemote;
    client.onRemoteStreamRemoved = _detachRemote;
    client.onParticipantsChanged = () {
      if (mounted) setState(() {});
    };
    // The renderer must finish initializing before a stream can be attached —
    // binding earlier silently leaves the preview black on devices.
    _localRenderer.initialize().then((_) {
      _rendererReady = true;
      _bindLocal();
    });
  }

  void _bindLocal() {
    if (!_rendererReady) return;
    final stream = widget.client.localStream;
    if (stream != null && widget.client.media == CallMedia.video && _localRenderer.srcObject != stream) {
      _localRenderer.srcObject = stream;
      if (mounted) setState(() {});
    }
  }

  void _onStateChanged(CallState state) {
    if (!mounted) return;
    if (state == CallState.idle || state == CallState.ended) {
      Navigator.of(context).maybePop();
      return;
    }
    _bindLocal();
    setState(() {});
  }

  Future<void> _attachRemote(String peerId, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    if (!mounted) {
      await renderer.dispose();
      return;
    }
    setState(() => _remoteRenderers[peerId] = renderer);
  }

  Future<void> _detachRemote(String peerId) async {
    final renderer = _remoteRenderers.remove(peerId);
    await renderer?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.client.onParticipantsChanged = null;
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final isVideo = client.media == CallMedia.video;
    final statusText = _statusLabel(client.state);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _stage(isVideo)),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            if (isVideo && _localRenderer.srcObject != null)
              Positioned(
                right: 16,
                top: 60,
                width: 108,
                height: 152,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),
            Positioned(left: 0, right: 0, bottom: 28, child: _controls(isVideo)),
          ],
        ),
      ),
    );
  }

  Widget _stage(bool isVideo) {
    final renderers = _remoteRenderers.values.toList();
    if (!isVideo || renderers.isEmpty) {
      if (widget.isGroup) return _participantStage();
      // 1:1 audio: avatar-style placeholder.
      return const Center(
        child: CircleAvatar(radius: 54, backgroundColor: Colors.white12, child: Icon(Icons.person_rounded, size: 56, color: Colors.white70)),
      );
    }
    if (renderers.length == 1) {
      return RTCVideoView(renderers.first, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
    }
    return GridView.count(
      crossAxisCount: 2,
      children: [for (final r in renderers) RTCVideoView(r, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)],
    );
  }

  // Group audio: a grid of everyone in the call.
  Widget _participantStage() {
    final people = widget.client.participants;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 130),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${people.length} ${people.length == 1 ? 'person' : 'people'} in the call',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 22),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 18,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [for (final p in people) _participantTile(p)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _participantTile(({String id, String name, bool isSelf, bool muted, bool speaking}) p) {
    // Admins can mute other (unmuted) participants.
    final canMute = widget.canManageRoom && !p.isSelf && !p.muted;
    final ringColor = p.speaking
        ? Colors.greenAccent
        : (p.isSelf ? Colors.tealAccent.withValues(alpha: .8) : Colors.white24);
    return SizedBox(
      width: 82,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: p.speaking ? 3 : 2),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white12,
              child: Text(_initials(p.name),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ),
          if (p.muted)
            Positioned(
              right: -2,
              bottom: -2,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black87,
                child: const Icon(Icons.mic_off_rounded, size: 14, color: Colors.white),
              ),
            ),
          if (canMute)
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () => widget.client.muteParticipant(p.id),
                child: const CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.mic_off_rounded, size: 13, color: Colors.white),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(p.name,
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  String _initials(String name) {
    if (name == 'You') return 'You';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Widget _controls(bool isVideo) {
    final client = widget.client;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundButton(
          icon: client.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          active: client.micEnabled,
          onTap: () => setState(client.toggleMic),
        ),
        if (isVideo) ...[
          const SizedBox(width: 18),
          _roundButton(
            icon: client.cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            active: client.cameraEnabled,
            onTap: () => setState(client.toggleCamera),
          ),
          const SizedBox(width: 18),
          _roundButton(icon: Icons.cameraswitch_rounded, active: true, onTap: client.switchCamera),
        ],
        const SizedBox(width: 18),
        _roundButton(
          icon: Icons.call_end_rounded,
          active: true,
          background: Colors.red,
          onTap: () {
            if (widget.isGroup) {
              client.leaveGroup();
            } else {
              client.hangUp();
            }
          },
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    Color? background,
  }) {
    return Material(
      color: background ?? (active ? Colors.white24 : Colors.white10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  String _statusLabel(CallState state) {
    switch (state) {
      case CallState.ringing:
        return 'Ringing…';
      case CallState.connecting:
        return 'Connecting…';
      case CallState.active:
        return widget.isGroup ? 'In the room' : 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.idle:
        return '';
    }
  }
}

/// A simple incoming-call sheet. Returns true to accept, false to decline.
Future<bool> showIncomingCallSheet(BuildContext context, IncomingCall call) async {
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              child: Icon(call.media == CallMedia.video ? Icons.videocam_rounded : Icons.call_rounded),
            ),
            const SizedBox(height: 14),
            Text(call.fromName, style: Theme.of(context).textTheme.titleLarge),
            Text(call.media == CallMedia.video ? 'Incoming video call' : 'Incoming call',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text('Decline'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return accepted ?? false;
}
