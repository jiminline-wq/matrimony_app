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
// MAIN — 🚀 "Load First" Strategy
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // STEP 1: শুধু Firebase init করুন (দ্রুততম, 필수)
  // ============================================================
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // STEP 2: সাথে সাথে UI দেখান! (আগে এখানেই আটকে থাকত)
  // ============================================================
  runApp(const JibonSathiApp());

  // ============================================================
  // STEP 3: বাকি সব background-এ চালান (UI ব্লক করবে না)
  // ============================================================
  _runBackgroundInit();
}

// ============================================================
// BACKGROUND INITIALIZATION — UI চলার সময় চলবে
// ============================================================
Future<void> _runBackgroundInit() async {
  // ১. Analytics (web-এ কাজ করে)
  try {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  } catch (e) {
    debugPrint('⚠️ Analytics init failed: $e');
  }

  // ২. FCM (web + mobile দুটোতেই কাজ করে)
  try {
    if (kIsWeb) {
      // Web FCM
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FcmService.initialize();
    } else {
      // Mobile FCM
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FcmService.initialize();
    }
  } catch (e) {
    debugPrint('⚠️ FCM init failed: $e');
  }

  // ৩. Native-only কাজ — শুধু mobile-এ (web-এ skip)
  if (!kIsWeb) {
    try {
      await _requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('⚠️ CallKit permission failed: $e');
    }

    try {
      await _requestBatteryOptimizationExemption();
    } catch (e) {
      debugPrint('⚠️ Battery optimization failed: $e');
    }

    try {
      await _initUmpConsent();
    } catch (e) {
      debugPrint('⚠️ UMP consent failed: $e');
    }

    try {
      await AdManager.initialize();
    } catch (e) {
      debugPrint('⚠️ AdMob init failed: $e');
    }
  }

  // ৪. Stale calls cleanup — ৫ সেকেন্ড পরে (UI সম্পূর্ণ লোড হওয়ার পর)
  Future.delayed(const Duration(seconds: 5), () async {
    try {
      final cleaned = await CallService.cleanupStaleCalls();
      if (cleaned > 0) {
        debugPrint('🧹 Cleaned up $cleaned stale calls');
      }
    } catch (e) {
      debugPrint('⚠️ cleanupStaleCalls failed: $e');
    }
  });

  // ৫. Expired stories cleanup — ৮ সেকেন্ড পরে
  Future.delayed(const Duration(seconds: 8), () async {
    try {
      final stories = await StoryService.cleanupExpired();
      if (stories > 0) {
        debugPrint('🧹 Cleaned $stories expired stories');
      }
    } catch (e) {
      debugPrint('⚠️ Story cleanup failed: $e');
    }
  });
}

// ============================================================
// FULL-SCREEN INTENT PERMISSION (শুধু mobile)
// ============================================================
Future<void> _requestFullScreenIntentPermission() async {
  if (kIsWeb) return;
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
// BATTERY OPTIMIZATION EXEMPTION (শুধু mobile)
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
// UMP CONSENT (শুধু mobile)
// ============================================================
Future<void> _initUmpConsent() async {
  if (kIsWeb) return;
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
  String? _lastAcceptedCallId;

  @override
  void initState() {
    super.initState();
    // ✅ Web-এ CallKit listener বন্ধ (MissingPluginException এড়াতে)
    if (!kIsWeb) {
      _setupCallKitListener();
    }
    _schedulePendingNotification();
  }

  @override
  void dispose() {
    _callKitSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // CALLKIT EVENT LISTENER (শুধু mobile)
  // ============================================================
  void _setupCallKitListener() {
    if (kIsWeb) return;
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
  // ACCEPT
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

      if (_lastAcceptedCallId == callId) {
        debugPrint('⚠️ Duplicate accept ignored for call: $callId');
        return;
      }
      _lastAcceptedCallId = callId;

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

      final nav = NavigationService.navigatorKey.currentState;
      if (nav == null) {
        debugPrint('❌ Navigator not ready for accepted call');
        return;
      }

      debugPrint('📞 Opening CallScreen (isIncoming: false)');

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
            isIncoming: false,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ _handleCallAccept error: $e');
    }
  }

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

    // ✅ FIX (ধাপ ৪): আগের CallKit নোটিফিকেশন বন্ধ করুন (যদি থেকে থাকে)
    final callId = data['callId'] as String?;
    if (callId != null && !kIsWeb) {
      FlutterCallkitIncoming.endCall(callId).catchError((e) {
        debugPrint('⚠️ CallKit endCall (pending) error: $e');
      });
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
