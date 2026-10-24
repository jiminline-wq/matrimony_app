// ============================================================
// REWARDED AD MANAGER — Watch ad → Get reward
// ============================================================

import 'dart:async'; // ✅ Completer এর জন্য
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';

class RewardedAdManager {
  static RewardedAd? _rewardedAd;
  static bool _isLoading = false;
  static int _retryAttempt = 0;
  static const int _maxRetries = 3;

  // ✅ Callback — user ad শেষ পর্যন্ত দেখলে
  static VoidCallback? _onUserEarnedReward;

  // ============================================================
  // LOAD AD (pre-load so it's ready when user taps)
  // ============================================================
  static Future<void> loadAd() async {
    // ✅ ওয়েবে অ্যাড লোড হবে না
    if (kIsWeb) return;

    if (_rewardedAd != null) {
      debugPrint('✅ [RewardedAd] Already loaded');
      return;
    }
    if (_isLoading) {
      debugPrint('⏳ [RewardedAd] Already loading...');
      return;
    }

    _isLoading = true;
    debugPrint('⏳ [RewardedAd] Loading...');

    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _retryAttempt = 0;
          debugPrint('✅ [RewardedAd] Loaded successfully');

          // ✅ Setup full-screen callbacks
          _setupCallbacks(ad);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          _retryAttempt++;
          debugPrint(
              '❌ [RewardedAd] Failed to load (attempt $_retryAttempt): $error');

          // ✅ Retry with exponential backoff
          if (_retryAttempt <= _maxRetries) {
            final delay = Duration(seconds: _retryAttempt * 2);
            debugPrint('🔄 [RewardedAd] Retrying in ${delay.inSeconds}s...');
            Future.delayed(delay, loadAd);
          }
        },
      ),
    );
  }

  // ============================================================
  // SETUP CALLBACKS
  // ============================================================
  static void _setupCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 [RewardedAd] Shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('📺 [RewardedAd] Dismissed');
        ad.dispose();
        _rewardedAd = null;
        // ✅ Pre-load next ad
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ [RewardedAd] Failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        loadAd();
      },
    );
  }

  // ============================================================
  // CHECK READY
  // ============================================================
  // ✅ ওয়েবে কখনোই রেডি হবে না
  static bool get isReady => !kIsWeb && _rewardedAd != null;

  // ============================================================
  // SHOW AD + WAIT FOR REWARD (FIXED)
  // ============================================================
  static Future<bool> showAd({
    required VoidCallback onUserEarnedReward,
  }) async {
    // ✅ ওয়েবে সরাসরি false রিটার্ন করবে (যাতে ক্র্যাশ না করে)
    if (kIsWeb) {
      debugPrint('⚠️ [RewardedAd] Web does not support AdMob');
      return false;
    }

    // If not ready, try to load
    if (_rewardedAd == null) {
      debugPrint('⚠️ [RewardedAd] Not ready — loading now...');
      await loadAd();

      int waited = 0;
      while (_rewardedAd == null && waited < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }

      if (_rewardedAd == null) {
        debugPrint('❌ [RewardedAd] Still not ready after waiting');
        return false;
      }
    }

    final ad = _rewardedAd!;
    _onUserEarnedReward = onUserEarnedReward;

    // ✅ Completer — callback fire হলে resolve হবে
    final completer = Completer<bool>();

    // ✅ এই ad instance এর জন্য callback override
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 [RewardedAd] Shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('📺 [RewardedAd] Dismissed');
        ad.dispose();
        _rewardedAd = null;
        // user reward না পেয়ে dismiss করলে
        if (!completer.isCompleted) completer.complete(false);
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ [RewardedAd] Failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
        loadAd();
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint(
            '🎁 [RewardedAd] User earned reward: ${reward.amount} ${reward.type}');
        if (!completer.isCompleted) completer.complete(true); // ✅ এখানে
        _onUserEarnedReward?.call();
        _onUserEarnedReward = null;
      },
    );

    // ✅ আসল reward callback fire হওয়া পর্যন্ত অপেক্ষা
    return completer.future;
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _onUserEarnedReward = null;
  }
}
