import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

/// Fullscreen photo viewer: pinch-to-zoom, a shared-element Hero transition from
/// the bubble, and a one-tap save to the photo library.
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.bytes, required this.heroTag});

  final Uint8List bytes;
  final String heroTag;

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Gal.putImageBytes(bytes, album: 'stonechat');
      messenger.showSnackBar(const SnackBar(content: Text('Saved to Photos')));
    } on GalException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: ${e.type.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(tag: heroTag, child: Image.memory(bytes)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  _RoundButton(
                    icon: Icons.download_rounded,
                    onTap: () => _save(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
