import 'package:flutter/material.dart';

/// A full-screen image viewer: the whole (uncropped) image on a dark backdrop,
/// pinch/drag to zoom, tap or the close button to dismiss. Falls back to a
/// broken-image glyph if the picture can't load.
class FullImageView extends StatelessWidget {
  const FullImageView({super.key, required this.imageUrl, this.heroTag});

  final String imageUrl;
  final Object? heroTag;

  static void open(BuildContext context, String imageUrl, {Object? heroTag}) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FullImageView(imageUrl: imageUrl, heroTag: heroTag),
    ));
  }

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded,
              color: Colors.white54, size: 64),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white70)),
        ),
      ),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Stack(children: [
          Positioned.fill(child: image),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ]),
      ),
    );
  }
}
