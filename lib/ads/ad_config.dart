// ============================================================
// AD CONFIG — সব Ad Unit IDs এখানে
// ============================================================

import 'package:flutter/foundation.dart' show kDebugMode;

class AdConfig {
  // ------------------------------------------------------------
  // MODE — Debug = test ads, Release = production ads
  // ------------------------------------------------------------
  /// ✅ আপাতত রিলিজ মোডেও টেস্ট অ্যাড দেখার জন্য true করে রাখা হলো।
  /// অ্যাডমব অ্যাকাউন্ট ভেরিফাই হওয়ার পর এবং রিয়েল আইডি বসানোর পর
  /// আবার `kDebugMode` করে দেবেন।
  static bool get useTestAds => true; // ⚠️ পরে এখানে kDebugMode বসাবেন

  // ------------------------------------------------------------
  // TEST IDs (Google Official — development-এর জন্য safe)
  // ------------------------------------------------------------
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testNativeId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testAppOpenId = 'ca-app-pub-3940256099942544/9257395921';

  // ------------------------------------------------------------
  // PRODUCTION IDs (AdMob approval-এর পর replace করবেন)
  // ------------------------------------------------------------
  // ⚠️ TODO: AdMob account approve হলে নিচের XXXX/YYYY গুলো
  //          আপনার real ad unit ID দিয়ে replace করুন।
  static const String _prodBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodRewardedId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodNativeId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';
  static const String _prodAppOpenId = 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY';

  // ------------------------------------------------------------
  // GETTERS — auto switch based on useTestAds
  // ------------------------------------------------------------
  static String get bannerAdUnitId =>
      useTestAds ? _testBannerId : _prodBannerId;
  static String get interstitialAdUnitId =>
      useTestAds ? _testInterstitialId : _prodInterstitialId;
  static String get rewardedAdUnitId =>
      useTestAds ? _testRewardedId : _prodRewardedId;
  static String get nativeAdUnitId =>
      useTestAds ? _testNativeId : _prodNativeId;
  static String get appOpenAdUnitId =>
      useTestAds ? _testAppOpenId : _prodAppOpenId;

  // ------------------------------------------------------------
  // UMP CONSENT — EU / GDPR compliance
  // ------------------------------------------------------------
  /// true হলে app startup-এ consent form দেখাবে (শুধু EU user হলে)।
  /// AdMob account suspend এড়াতে এটা enable রাখা জরুরি।
  static const bool enableUmpConsent = true;

  // ------------------------------------------------------------
  // PLACEMENT IDs — analytics-এর জন্য (future use)
  // ------------------------------------------------------------
  // Bottom nav tabs
  static const String placementHome = 'home_banner';
  static const String placementDiscover = 'discover_banner';
  static const String placementMatches = 'matches_banner';
  static const String placementNearby = 'nearby_banner';
  static const String placementMyProfile = 'my_profile_banner';

  // Feature screens
  static const String placementChatList = 'chat_list_banner';
  static const String placementSaved = 'saved_banner';
  static const String placementWhoViewed = 'who_viewed_banner';
  static const String placementWhoLiked = 'who_liked_banner';
  static const String placementCallHistory = 'call_history_banner';
  static const String placementNotifications = 'notifications_banner';
  static const String placementStoryDetails = 'story_details_banner';
  static const String placementProfileView = 'profile_view_banner';
  static const String placementReferral = 'referral_banner';

  // Action-based
  static const String placementSaveAction = 'save_action_interstitial';
  static const String placementSwipeLike = 'swipe_like_interstitial';
  static const String placementFilterApply = 'filter_apply_interstitial';

  // Rewarded
  static const String placementBoost = 'boost_rewarded';
  static const String placementUnlockWhoLiked = 'unlock_who_liked';
  static const String placementUnlockWhoViewed = 'unlock_who_viewed';
  static const String placementExtraMessages = 'extra_messages_rewarded';
}
