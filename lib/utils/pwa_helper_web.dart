import 'dart:js_interop';

@JS('checkIsPwaInstalled')
external bool checkIsPwaInstalled();

@JS('triggerPwaInstall')
external JSPromise<JSBoolean> triggerPwaInstallJS();

bool isPwaInstalled() {
  try {
    return checkIsPwaInstalled();
  } catch (_) {
    return false;
  }
}

Future<bool> triggerPwaInstall() async {
  try {
    final res = await triggerPwaInstallJS().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}
