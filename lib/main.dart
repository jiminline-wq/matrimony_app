import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:permission_handler/permission_handler.dart';

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

// ============================================================
// MAIN
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ১. Firebase init
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ২. Notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ৩. FCM SETUP
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.initialize();

  // ৪. Full-Screen Intent Permission
  await _requestFullScreenIntentPermission();

  // ৪.১ Battery Optimization
  await _requestBatteryOptimizationExemption();

  // ৫. Analytics
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // ৬. UMP consent
  await _initUmpConsent();

  // ৭. AdMob
  await AdManager.initialize();

  // ৮. Stale Calls Cleanup
  try {
    final cleaned = await CallService.cleanupStaleCalls();
    if (cleaned > 0) {
      debugPrint('🧹 Cleaned up $cleaned stale calls at startup');
    }
  } catch (e) {
    debugPrint('⚠️ cleanupStaleCalls failed: $e');
  }

  // ৯. Expired Stories Cleanup
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
// FULL-SCREEN INTENT PERMISSION
// ============================================================
Future<void> _requestFullScreenIntentPermission() async {
  try {
    final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
    if (!canUse) {
      debugPrint('📞 Requesting full-screen intent permission...');
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } else {
      debugPrint('✅ Full-screen intent permission already granted');
    }
  } catch (e) {
    debugPrint('⚠️ Full-screen intent permission error: $e');
  }
}

// ============================================================
// BATTERY OPTIMIZATION EXEMPTION
// ============================================================
Future<void> _requestBatteryOptimizationExemption() async {
  if (kIsWeb) return;

  try {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      debugPrint('✅ Battery optimization already ignored');
      return;
    }
    final result = await Permission.ignoreBatteryOptimizations.request();
    debugPrint('🔋 Battery optimization request result: $result');
  } catch (e) {
    debugPrint('⚠️ Battery optimization request failed: $e');
  }
}

// ============================================================
// UMP CONSENT
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
  StreamSubscription<CallEvent?>? _callKitSubscription;
  String? _lastAcceptedCallId; // ✅ ডুপ্লিকেট Accept ঠেকাতে

  @override
  void initState() {
    super.initState();
    _setupCallKitListener();
    _schedulePendingNotification();
  }

  @override
  void dispose() {
    _callKitSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // CALLKIT EVENT LISTENER
  // ============================================================
  void _setupCallKitListener() {
    _callKitSubscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;

      final eventName = event.event;
      debugPrint('📞 CallKit event: $eventName');

      if (eventName == 'actionCallAccept') {
        _handleCallAccept(event.body);
      } else if (eventName == 'actionCallDecline') {
        _handleCallDecline(event.body);
      } else if (eventName == 'actionCallEnd') {
        _handleCallEnd(event.body);
      } else if (eventName == 'actionCallTimeout') {
        _handleCallTimeout(event.body);
      }
    });
  }

  // ============================================================
  // ACCEPT — Firestore আপডেট করে তারপর CallScreen খুলুন
  // ============================================================
  Future<void> _handleCallAccept(dynamic body) async {
    try {
      final extra = _extractExtra(body);
      if (extra == null) {
        debugPrint('❌ Call accepted but extra is null');
        return;
      }

      final callId = extra['callId'] as String?;
      final channelName = extra['channelName'] as String?;

      if (callId == null || channelName == null) {
        debugPrint('❌ Call accepted but callId/channelName missing');
        return;
      }

      // ✅ ডুপ্লিকেট accept ঠেকান
      if (_lastAcceptedCallId == callId) {
        debugPrint('⚠️ Duplicate accept ignored for call: $callId');
        return;
      }
      _lastAcceptedCallId = callId;

      // ✅ প্রথমে Firestore-এ status 'accepted' করুন
      // এতে CallScreen খোলার সময় status দেখে আর Receive button দেখাবে না
      try {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'accepted',
          'answeredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Firestore updated: call $callId accepted');
      } catch (e) {
        debugPrint('⚠️ Could not update call status to accepted: $e');
      }

      // ✅ Navigator ready কিনা চেক করুন
      final nav = NavigationService.navigatorKey.currentState;
      if (nav == null) {
        debugPrint('❌ Navigator not ready for accepted call');
        return;
      }

      debugPrint('📞 Opening CallScreen (isIncoming: false)');

      // ✅ isIncoming: false — কারণ ইউজার ইতিমধ্যেই Accept করেছে
      nav.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            isBangla: true,
            channelName: channelName,
            otherUserName: extra['callerName'] ?? 'Unknown',
            otherUserPhoto: extra['callerPhoto'] ?? '',
            isVideoCall: extra['isVideoCall'] == 'true',
            isCaller: false,
            callId: callId,
            isIncoming: false, // ✅ এটাই মূল ফিক্স
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ _handleCallAccept error: $e');
    }
  }

  // ============================================================
  // DECLINE
  // ============================================================
  Future<void> _handleCallDecline(dynamic body) async {
    try {
      final extra = _extractExtra(body);
      final callId = extra?['callId'];
      if (callId != null) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'declined',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('⚠️ Could not update call as declined: $e');
        });
        debugPrint('📞 Call declined: $callId');
      }
    } catch (e) {
      debugPrint('❌ _handleCallDecline error: $e');
    }
  }

  // ============================================================
  // CALL END
  // ============================================================
  Future<void> _handleCallEnd(dynamic body) async {
    try {
      final extra = _extractExtra(body);
      final callId = extra?['callId'];
      if (callId != null) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('⚠️ Could not update call as ended: $e');
        });
        debugPrint('📞 Call ended via CallKit: $callId');
        _lastAcceptedCallId = null;
      }
    } catch (e) {
      debugPrint('❌ _handleCallEnd error: $e');
    }
  }

  // ============================================================
  // TIMEOUT
  // ============================================================
  Future<void> _handleCallTimeout(dynamic body) async {
    try {
      final extra = _extractExtra(body);
      final callId = extra?['callId'];
      if (callId != null) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callId)
            .update({
          'status': 'missed',
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          debugPrint('⚠️ Could not update call as missed: $e');
        });
        debugPrint('📞 Call timeout: $callId');
      }
    } catch (e) {
      debugPrint('❌ _handleCallTimeout error: $e');
    }
  }

  // ============================================================
  // EXTRACT EXTRA
  // ============================================================
  Map<String, dynamic>? _extractExtra(dynamic body) {
    if (body == null) return null;
    if (body is! Map) return null;

    final extra = body['extra'];
    if (extra is Map<String, dynamic>) return extra;
    if (extra is Map) return Map<String, dynamic>.from(extra);

    try {
      return Map<String, dynamic>.from(body);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // PENDING NOTIFICATION
  // ============================================================
  Future<void> _schedulePendingNotification() async {
    final start = DateTime.now();
    while (NavigationService.navigatorKey.currentState == null) {
      if (DateTime.now().difference(start).inSeconds > 8) {
        debugPrint('❌ Navigator never became ready');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }

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
          isIncoming: true, // pending notification থেকে এলে receive দেখাবে
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
