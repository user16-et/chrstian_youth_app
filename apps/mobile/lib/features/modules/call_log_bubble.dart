import 'package:flutter/material.dart';

import '../../i18n/app_i18n.dart';

/// A Telegram-style call entry inside a conversation. Reads a message's
/// `metadata` (kind == 'call') and renders direction, outcome, media and
/// duration; tapping it calls back.
class CallLogBubble extends StatelessWidget {
  const CallLogBubble({
    super.key,
    required this.metadata,
    required this.isOutgoing,
    required this.language,
    required this.createdAt,
    this.onCallBack,
  });

  final Map<String, dynamic> metadata;
  final bool isOutgoing; // did the current user place this call?
  final AppLanguage language;
  final String createdAt;
  final VoidCallback? onCallBack;

  bool get _en => language == AppLanguage.english;
  String _t(String en, String am) => _en ? en : am;

  bool get _isVideo => metadata['media']?.toString() == 'video';
  String get _outcome => metadata['outcome']?.toString() ?? 'completed';
  bool get _outgoing => isOutgoing;
  int get _duration => (metadata['durationSeconds'] as num?)?.toInt() ?? 0;

  // A red entry for the calls a person would want to notice they lost.
  bool get _isMissedForMe =>
      (_outcome == 'missed' || _outcome == 'cancelled') && !_outgoing ||
      (_outcome == 'declined' && !_outgoing);

  String _durationLabel() {
    final s = _duration;
    if (s <= 0) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }

  String _title() {
    switch (_outcome) {
      case 'completed':
        final kind = _isVideo ? _t('video call', 'የቪዲዮ ጥሪ') : _t('call', 'ጥሪ');
        return _outgoing ? _t('Outgoing ', 'የወጣ ') + kind : _t('Incoming ', 'የገባ ') + kind;
      case 'declined':
        return _outgoing ? _t('Call declined', 'ጥሪ ተቀባይነት አላገኘም') : _t('Declined call', 'ውድቅ የተደረገ ጥሪ');
      case 'missed':
      case 'cancelled':
      default:
        return _outgoing ? _t('No answer', 'መልስ አልተገኘም') : _t('Missed call', 'ያመለጠ ጥሪ');
    }
  }

  IconData get _icon {
    if (_outcome == 'missed' || _outcome == 'cancelled' || _outcome == 'declined') {
      return _outgoing ? Icons.call_missed_outgoing_rounded : Icons.call_missed_rounded;
    }
    return _outgoing ? Icons.call_made_rounded : Icons.call_received_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _isMissedForMe ? colors.error : colors.primary;
    final duration = _durationLabel();
    return Align(
      alignment: _outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Material(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onCallBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    size: 20, color: accent),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_icon, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(_title(),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _isMissedForMe ? colors.error : colors.onSurface)),
                    ]),
                    Text(
                      duration.isEmpty
                          ? _t('Tap to call back', 'ለመመለስ ይንኩ')
                          : duration,
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
                if (onCallBack != null) ...[
                  const SizedBox(width: 12),
                  Icon(_isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                      size: 18, color: colors.onSurfaceVariant),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
