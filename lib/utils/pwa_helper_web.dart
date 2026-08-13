import 'dart:js_interop';

@JS('checkIsPwaInstalled')
external bool checkIsPwaInstalled();

@JS('triggerPwaInstall')
external JSPromise<JSBoolean> triggerPwaInstallJS();

@JS('isIOSDevice')
external bool isIOSDeviceJS();

@JS('isAndroidDevice')
external bool isAndroidDeviceJS();

@JS('hasDeferredPwaPrompt')
external bool hasDeferredPwaPromptJS();

bool isPwaInstalled() {
  try { return checkIsPwaInstalled(); } catch (_) { return false; }
}

bool isIOSPlatform() {
  try { return isIOSDeviceJS(); } catch (_) { return false; }
}

bool isAndroidPlatform() {
  try { return isAndroidDeviceJS(); } catch (_) { return false; }
}

bool hasNativePwaPrompt() {
  try { return hasDeferredPwaPromptJS(); } catch (_) { return false; }
}

Future<bool> triggerPwaInstall() async {
  try {
    final res = await triggerPwaInstallJS().toDart;
    return res.toDart;
  } catch (_) {
    return false;
  }
}
