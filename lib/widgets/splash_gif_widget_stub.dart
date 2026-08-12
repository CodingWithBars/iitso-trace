// Mobile/Desktop stub — uses Flutter's Image.asset for GIF rendering
import 'package:flutter/material.dart';

class SplashGifWidget extends StatelessWidget {
  final double size;

  const SplashGifWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/splash-logo.gif',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // gaplessPlayback false = always restart from frame 0
      gaplessPlayback: false,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/trace-logo3.png',
          width: size * 0.6,
          height: size * 0.6,
        );
      },
    );
  }
}
