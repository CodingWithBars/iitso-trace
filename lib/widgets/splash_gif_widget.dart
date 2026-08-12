// Conditional export:
// - On Web (dart:ui_web available): uses HtmlElementView for native browser GIF animation
// - On Mobile/Desktop: uses Image.asset
export 'splash_gif_widget_stub.dart'
    if (dart.library.ui_web) 'splash_gif_widget_web.dart';
