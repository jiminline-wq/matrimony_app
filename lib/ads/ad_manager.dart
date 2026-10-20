// ============================================================
// AD MANAGER — Central AdMob handler
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static bool _initialized = false;

  static bool get isReady => _initialized;

  // ============================================================
  // INITIALIZE — app start-এ একবার call হবে
  // ============================================================
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('✅ AdMob initialized');
    } catch (e) {
      debugPrint('❌ AdMob init failed: $e');
    }
  }
}
