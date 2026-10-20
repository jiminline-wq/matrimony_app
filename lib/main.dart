import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_options.dart';
import 'theme/colors.dart';
import 'screens/splash_screen.dart';
import 'screens/call_screen.dart';
import 'services/fcm_service.dart';
import 'services/call_service.dart';
import 'utils/navigation_service.dart';
import 'ads/ad_config.dart';
import 'ads/ad_manager.dart';
import 'services/story_service.dart';

// ⚠️ Migration চালানোর সময় নিচের import টা uncomment করবেন
// import 'utils/district_migration.dart';

// ============================================================
// MAIN
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ১. Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  // ২. ✅ FCM SETUP (অবশ্যই runApp এর আগে থাকতে হবে)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.initialize();

  // ৩. Analytics enable
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // ৪. UMP consent — AdMob init-এর আগে (EU/GDPR compliance)
  await _initUmpConsent();

  // ৫. AdMob initialize (consent-এর পরে)
  await AdManager.initialize();

  // ============================================================
  // ৬. STALE CALL CLEANUP
  // ============================================================
  try {
    final cleaned = await CallService.cleanupStaleCalls();
    if (cleaned > 0) {
      debugPrint('🧹 Cleaned up $cleaned stale calls at startup');
    }
  } catch (e) {
    debugPrint('⚠️ cleanupStaleCalls failed: $e');
  }

  // ============================================================
  // ৭. EXPIRED STORIES CLEANUP
  // ============================================================
  try {
    final stories = await StoryService.cleanupExpired();
    if (stories > 0) {
      debugPrint('🧹 Cleaned $stories expired stories');
    }
  } catch (e) {
    debugPrint('⚠️ Story cleanup failed: $e');
  }

  runApp(const JibonSathiApp());
}

// ============================================================
// UMP CONSENT — EU / GDPR
// ============================================================
Future<void> _initUmpConsent() async {
  if (!AdConfig.enableUmpConsent) return;

  try {
    final params = ConsentRequestParameters();
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired(
            (FormError? error) {
              if (error != null) {
                debugPrint('⚠️ UMP form error: ${error.message}');
              }
              if (!completer.isCompleted) completer.complete();
            },
          );
        } catch (e) {
          debugPrint('⚠️ UMP load error: $e');
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) {
        debugPrint('⚠️ UMP request error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    // ⏱️ 10s timeout — user form ignore করলে hang করবে না
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint('⚠️ UMP consent timeout — continuing'),
    );
  } catch (e) {
    debugPrint('⚠️ UMP init failed (continuing): $e');
  }
}

// ============================================================
// APP
// ============================================================
class JibonSathiApp extends StatefulWidget {
  const JibonSathiApp({super.key});

  @override
  State<JibonSathiApp> createState() => _JibonSathiAppState();
}

class _JibonSathiAppState extends State<JibonSathiApp> {
  bool _pendingProcessed = false;

  @override
  void initState() {
    super.initState();
    _schedulePendingNotification();
  }

  // ============================================================
  // PENDING NOTIFICATION (robust)
  // ============================================================
  Future<void> _schedulePendingNotification() async {
    // 1) Wait for Navigator to be attached (max 8s)
    final start = DateTime.now();
    while (NavigationService.navigatorKey.currentState == null) {
      if (DateTime.now().difference(start).inSeconds > 8) {
        debugPrint('❌ Navigator never became ready');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // 2) Give splash a natural moment
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted || _pendingProcessed) return;
    _pendingProcessed = true;

    final pending = NavigationService.consumePending();
    if (pending == null) return;

    debugPrint('📌 Processing pending notification: $pending');

    if (pending['type'] == 'call') {
      _openCallScreen(pending);
      return;
    }

    await NavigationService.handleNotificationTap(pending);
  }

  void _openCallScreen(Map<String, dynamic> data) {
    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) {
      debugPrint('❌ Navigator not ready for call screen');
      return;
    }

    debugPrint('📞 Opening CallScreen from pending notification');

    nav.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          isBangla: true,
          channelName: data['channelName'] ?? '',
          otherUserName: data['callerName'] ?? 'Unknown',
          otherUserPhoto: data['callerPhoto'] ?? '',
          isVideoCall: data['isVideoCall'] == 'true',
          isCaller: false,
          callId: data['callId'],
          isIncoming: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'জীবন সাথী',
      navigatorKey: NavigationService.navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: warmWhite,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryMaroon),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
