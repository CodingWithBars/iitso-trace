// Web implementation — uses HtmlElementView so the browser natively
// animates the GIF. Flutter Web CanvasKit renderer cannot animate GIFs
// through Image.asset (only renders frame 0). This bypasses that limitation.
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';

class SplashGifWidget extends StatefulWidget {
  final double size;

  const SplashGifWidget({super.key, required this.size});

  @override
  State<SplashGifWidget> createState() => _SplashGifWidgetWebState();
}

class _SplashGifWidgetWebState extends State<SplashGifWidget> {
  static bool _viewRegistered = false;
  // Unique viewType per widget instance so each mount gets a fresh <img>
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    // Each instance gets a unique viewType key so the browser creates a
    // fresh <img> element and plays the GIF from frame 0 every launch.
    _viewType = 'splash-gif-view-$hashCode';

    if (!_viewRegistered) {
      _viewRegistered = true;
    }

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final img =
            web.document.createElement('img') as web.HTMLImageElement;

        // Append cache-buster so the browser always fetches fresh GIF frames
        img.src =
            'assets/splash-logo.gif?t=${DateTime.now().millisecondsSinceEpoch}';
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.objectFit = 'contain';
        img.style.borderRadius = '20px';
        // Ensure transparent background (GIF with alpha over gradient)
        img.style.background = 'transparent';
        return img;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
