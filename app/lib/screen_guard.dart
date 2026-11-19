// Developed by Codesoftwares
import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording (Android FLAG_SECURE) through a tiny native channel in MainActivity.
/// On web, iOS and desktop the channel does not exist and the call is ignored.
class ScreenGuard {
  static const _ch = MethodChannel('nari_shakthi/secure');
  static Future<void> set(bool on) async {
    try {
      await _ch.invokeMethod(on ? 'on' : 'off');
    } catch (_) {/* no native side on this platform */}
  }
}
