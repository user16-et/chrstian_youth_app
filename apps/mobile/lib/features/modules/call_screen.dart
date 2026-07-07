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
  });

  final CallClient client;
  final String title;
  final bool isGroup;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    final client = widget.client;
    client.onStateChanged = _onStateChanged;
    client.onRemoteStream = _attachRemote;
    client.onRemoteStreamRemoved = _detachRemote;
    _bindLocal();
  }

  Future<void> _bindLocal() async {
    final stream = widget.client.localStream;
    if (stream != null && widget.client.media == CallMedia.video) {
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
      // Audio call / not yet connected: avatar-style placeholder.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.white12,
              child: Icon(widget.isGroup ? Icons.groups_rounded : Icons.person_rounded, size: 56, color: Colors.white70),
            ),
            if (widget.isGroup) ...[
              const SizedBox(height: 16),
              Text('${renderers.length + 1} in the room',
                  style: const TextStyle(color: Colors.white70)),
            ],
          ],
        ),
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
