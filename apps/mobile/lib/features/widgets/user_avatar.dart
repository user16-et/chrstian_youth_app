import 'package:flutter/material.dart';

/// A user's avatar, shown consistently everywhere. If [imageUrl] is present it
/// shows the photo; otherwise it falls back to the person's initials on a
/// deterministic color — so every user always has a recognizable avatar, even
/// without an uploaded picture.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.seed,
    this.radius = 20,
  });

  final String name;
  final String? imageUrl;
  final String? seed; // stable color source (e.g. user id); defaults to name
  final double radius;

  // Calm, legible background tints (white text sits well on all of these).
  static const List<Color> _palette = [
    Color(0xFF1E88E5), Color(0xFF00897B), Color(0xFF43A047), Color(0xFF7CB342),
    Color(0xFFF4511E), Color(0xFFD81B60), Color(0xFF8E24AA), Color(0xFF5E35B1),
    Color(0xFF3949AB), Color(0xFF00ACC1), Color(0xFFFB8C00), Color(0xFF6D4C41),
  ];

  Color _background() {
    final key = (seed?.isNotEmpty == true ? seed! : name);
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  String _initials() {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    // Ethiopic and Latin letters are single UTF-16 code units, so substring is
    // safe here.
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final background = _background();
    final label = Text(
      _initials(),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.8,
      ),
    );
    // foregroundImage overlays the initials when it loads, and the initials
    // remain visible if the URL is empty or fails.
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
          ? NetworkImage(imageUrl!)
          : null,
      onForegroundImageError:
          (imageUrl != null && imageUrl!.isNotEmpty) ? (_, __) {} : null,
      child: label,
    );
  }
}
