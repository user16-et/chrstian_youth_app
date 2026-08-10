import 'package:flutter/material.dart';

/// A shareable, self-contained verse graphic. Uses fixed brand colors (not the
/// viewer's theme) so the captured image looks the same wherever it's shared.
class VerseCard extends StatelessWidget {
  const VerseCard({
    super.key,
    required this.reference,
    required this.text,
    this.footer = 'Christian Youth',
  });

  final String reference;
  final String text;
  final String footer;

  static const Color _top = Color(0xFF06342C); // forest
  static const Color _bottom = Color(0xFF0E7C6B); // evergreen
  static const Color _gold = Color(0xFFE6B325);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_top, _bottom],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: _gold, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            reference.toUpperCase(),
            style: const TextStyle(
              color: _gold,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(Icons.church_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                footer,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
