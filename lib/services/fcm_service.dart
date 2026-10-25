import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

import '../firebase_options.dart';
import '../utils/navigation_service.dart';

// ============================================================
// ✅ FCM BACKGROUND HANDLER (mobile only)
// ============================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['type'];
  debugPrint('🔔 [BACKGROUND] Message received: $type');

  if (type == 'call') {
    await FcmService.showCallKitIncoming(message);
  } else {
    await FcmService.showBackgroundGeneralNotification(message);
  }
}

// ============================================================
// FCM SERVICE
// ============================================================
class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedAppSub;

  // ✅ Web VAPID key — Firebase Console → Cloud Messaging → Web Push certificates
  // এই key টি অবশ্যই বসাতে হবে, নাহলে Web-এ FCM token পাওয়া যাবে না
  static const String _webVapidKey =
      'BDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  static const _callChannel = AndroidNotificationChannel(
    'call_channel_v9',
    'Incoming Calls',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ringtone'),
    enableVibration: true,
  );

  static const _generalChannel = AndroidNotificationChannel(
    'general_channel_v5',
    'General Notifications',
    importance: Importance.high,
    playSound: true,
  );

  // ============================================================
  // INITIALIZE
  // ============================================================
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (kIsWeb) {
        await _initializeWeb();
        return;
      }
      await _initializeMobile();
    } catch (e) {
      debugPrint('❌ FCM init error: $e');
      _initialized = false;
    }
  }

  // ============================================================
  // ✅ WEB INITIALIZATION
  // ============================================================
  static Future<void> _initializeWeb() async {
    debugPrint('🌐 [WEB] Initializing FCM...');

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🌐 [WEB] Permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ [WEB] Notification permission denied');
        return;
      }

      // ✅ VAPID key দিয়ে Web FCM token নিন
      final token = await _messaging.getToken(vapidKey: _webVapidKey);
      debugPrint('🌐 [WEB] FCM token: ${token?.substring(0, 20)}...');
      if (token != null) await _saveTokenToFirestore(token);
      _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // ✅ Web foreground messages — browser নিজেই notification দেখাবে
      // তবে আমরা log রাখছি debugging-এর জন্য
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('🔔 [WEB] Foreground message: ${message.data}');
        if (message.data['type'] == 'call') {
          // Web-এ foreground-এ কল এলে Notification API ব্যবহার করতে পারি
          // অথবা সরাসরি call screen-এ navigate
          NavigationService.handleNotificationTap(
            Map<String, dynamic>.from(message.data),
          );
        }
      });

      // ✅ Tab click করে open হলে (from notification)
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('🔔 [WEB] Message opened app: ${message.data}');
        NavigationService.handleNotificationTap(
          Map<String, dynamic>.from(message.data),
        );
      });

      // ✅ Page load হলে pending message চেক
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [WEB] Initial message: ${initialMessage.data}');
        NavigationService.handleNotificationTap(
          Map<String, dynamic>.from(initialMessage.data),
        );
      }

      debugPrint('✅ [WEB] FCM initialized successfully');
    } catch (e) {
      debugPrint('❌ [WEB] FCM init failed: $e');
    }
  }

  // ============================================================
  // ✅ MOBILE INITIALIZATION (আগের কোড অপরিবর্তিত)
  // ============================================================
  static Future<void> _initializeMobile() async {
    final settings = await _messaging.requestPermission(
        alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);

          if (data['callId'] != null) {
            cancelCallNotification(data['callId'].hashCode);
          }

          NavigationService.handleNotificationTap(
            Map<String, dynamic>.from(data),
          );
        }
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_callChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);

    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToFirestore(token);
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('🔔 Foreground message: ${message.data}');
      if (message.data['type'] == 'call') {
        showCallKitIncoming(message);
      } else {
        _showForegroundGeneralNotification(message);
      }
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('🔔 Message opened app: ${message.data}');
      final data = message.data;
      if (data['callId'] != null) {
        cancelCallNotification(data['callId'].hashCode);
      }
      NavigationService.handleNotificationTap(
        Map<String, dynamic>.from(data),
      );
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 Initial message: ${initialMessage.data}');
      final data = initialMessage.data;
      if (data['callId'] != null) {
        cancelCallNotification(data['callId'].hashCode);
      }
      NavigationService.handleNotificationTap(
        Map<String, dynamic>.from(data),
      );
    }
  }

  // ============================================================
  // CANCELLATION
  // ============================================================
  static Future<void> cancelCallNotification(int notificationId) async {
    if (kIsWeb) return;
    try {
      await _localNotifications.cancel(notificationId);
      debugPrint('🔕 Call notification cancelled: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to cancel call notification: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _localNotifications.cancelAll();
  }

  // ============================================================
  // FOREGROUND GENERAL NOTIFICATION
  // ============================================================
  static Future<void> _showForegroundGeneralNotification(
      RemoteMessage message) async {
    if (kIsWeb) return;
    final data = message.data;
    final title = data['title'] ?? 'নতুন বার্তা';
    final body = data['body'] ?? 'আপনার জন্য নতুন নোটিফিকেশন আছে';

    final androidDetails = AndroidNotificationDetails(
      'general_channel_v5',
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  // ============================================================
  // BACKGROUND GENERAL NOTIFICATION
  // ============================================================
  static Future<void> showBackgroundGeneralNotification(
      RemoteMessage message) async {
    if (kIsWeb) return;
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif
        .initialize(const InitializationSettings(android: androidInit));

    final androidPlugin = localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_generalChannel);

    final data = message.data;
    final title = data['title'] ?? 'নতুন বার্তা';
    final body = data['body'] ?? 'আপনার জন্য নতুন নোটিফিকেশন আছে';

    final androidDetails = AndroidNotificationDetails(
      'general_channel_v5',
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      autoCancel: true,
    );

    await localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  // ============================================================
  // CALL — CallKit (mobile) / Skip (web)
  // ============================================================
  static Future<void> showCallKitIncoming(RemoteMessage message) async {
    if (kIsWeb) return; // Web-এ CallKit নেই — SW notification ব্যবহার করবে

    debugPrint('🚨 [CALLKIT] Incoming call! Data: ${message.data}');

    final data = message.data;
    final isVideoCall =
        data['isVideoCall'] == 'true' || data['isVideoCall'] == true;
    final callerName = data['callerName'] ?? 'Someone';
    final callId = data['callId'] ?? const Uuid().v4();

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'জীবন সাথী',
      avatar: data['callerPhoto'],
      type: isVideoCall ? 1 : 0,
      duration: 30000,
      extra: Map<String, dynamic>.from(data),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#2E2727',
      ),
      ios: const IOSParams(
        supportsVideo: true,
        audioSessionActive: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    debugPrint('✅ CallKit shown for callId: $callId');
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================
  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('⚠️ Cannot save token — user not logged in');
      return;
    }
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
    debugPrint('✅ Token saved to Firestore: ${token.substring(0, 20)}...');
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token])
      }, SetOptions(merge: true));
    }
  }
}
