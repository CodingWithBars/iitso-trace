// Web-platform URL opener using package:web (dart:js_interop compatible)
import 'package:web/web.dart' as web;

void openUrlOnWeb(String url) {
  web.window.open(url, '_blank');
}
