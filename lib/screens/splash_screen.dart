import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/splash_gif_widget.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final String? targetPath;
  const SplashScreen({super.key, this.targetPath});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Fade-IN: splash screen fades in smoothly
  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;

  // ── Fade-OUT: black curtain fades in before navigating to landing screen
  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutAnimation;

  Timer? _timer;
  bool _gifReady = false;

  @override
  void initState() {
    super.initState();

    // ── Step 1: Evict GIF cache synchronously (mobile only — web uses
    //            HtmlElementView which bypasses Flutter's image cache entirely)
    if (!kIsWeb) {
      PaintingBinding.instance.imageCache.evict(
        const AssetImage('assets/splash-logo.gif'),
      );
    }

    // ── Step 2: Fade-IN animation (700ms easeOut)
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeOut),
    );

    // ── Step 3: Fade-OUT overlay animation (600ms easeIn)
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeOutAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ── Step 4a: On mobile, precache GIF for smooth first frame.
      //             On web, HtmlElementView handles its own loading natively.
      if (!kIsWeb) {
        await precacheImage(
          const AssetImage('assets/splash-logo.gif'),
          context,
        );
      }

      if (!mounted) return;
      setState(() => _gifReady = true);

      // ── Step 4b: Start fade-in animation
      _fadeInController.forward();

      // ── Step 5: Preload landing screen assets in background during splash
      _preloadLandingAssets();

      // ── Step 6: Hold for 2.8 seconds then trigger smooth fade-out exit
      _timer = Timer(const Duration(milliseconds: 2800), _startExitSequence);
    });
  }

  /// Preloads all images used by the landing screen in the background
  /// so they render instantly when the user arrives there.
  void _preloadLandingAssets() {
    if (!mounted) return;
    final assets = [
      'assets/hero-image.png',
      'assets/trace-logo3.png',
      'assets/1.png',
      'assets/2.png',
      'assets/3.png',
    ];
    for (final asset in assets) {
      precacheImage(AssetImage(asset), context).catchError((_) {
        // Silently ignore missing optional assets
      });
    }
  }

  Future<void> _startExitSequence() async {
    if (!mounted) return;
    if (_fadeOutController.isAnimating || _fadeOutController.isCompleted) return;
    _timer?.cancel();

    // Play the black curtain fade-out overlay before navigating
    await _fadeOutController.forward();

    if (!mounted) return;
    final destination = widget.targetPath ?? '/';
    final target = (destination == '/splash') ? '/' : destination;
    context.go(target);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeInController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    // Logo at 40% of previous size: 155px desktop, 32% of screen width mobile
    final logoSize = isMobile ? (size.width * 0.32) : 155.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _startExitSequence,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Gradient background (always visible, no stutter)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF050505), // Deep luxury black top
                    Color(0xFF160A04), // Dark chocolate transition
                    Color(0xFF3E1505), // Rich dark orange middle
                    Color(0xFF8B2500), // Burnt orange bottom gradient
                    Color(0xFFFF5722), // Vibrant accent orange base
                  ],
                  stops: [0.0, 0.35, 0.65, 0.90, 1.0],
                ),
              ),
            ),

            // ── Layer 2: Centered GIF logo with fade-in
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Center(
                child: _gifReady
                    ? Container(
                        width: logoSize,
                        height: logoSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5722).withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 30,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          // ── SplashGifWidget: Web → HtmlElementView (native browser GIF)
                          //                    Mobile → Image.asset
                          child: SplashGifWidget(size: logoSize),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // ── Layer 3: Black fade-out curtain (plays before navigation)
            AnimatedBuilder(
              animation: _fadeOutAnimation,
              builder: (context, _) {
                if (_fadeOutAnimation.value == 0) return const SizedBox.shrink();
                return Opacity(
                  opacity: _fadeOutAnimation.value,
                  child: const ColoredBox(
                    color: Color(0xFF050505),
                    child: SizedBox.expand(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
