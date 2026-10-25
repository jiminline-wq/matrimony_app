import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../utils/navigation_service.dart';

// ============================================================
// ✅ FCM BACKGROUND HANDLER
// ============================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['type'];
  debugPrint('🔔 [BACKGROUND] Message received: $type');

  if (type == 'call') {
    await FcmService.showBackgroundCallNotification(message);
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
    if (_initialized || kIsWeb)
      return; // ওয়েবে FCM লোকাল নোটিফিকেশন এড়ানোর জন্য
    _initialized = true;

    try {
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
          // ফোরগ্রাউন্ডে কল আসলে সরাসরি কল স্ক্রিনে রিডাইরেক্ট করতে পারেন অথবা ফুল-স্ক্রিন দেখাতে পারেন
          showBackgroundCallNotification(message);
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
    } catch (e) {
      debugPrint('❌ FCM init error: $e');
      _initialized = false;
    }
  }

  // ============================================================
  // CANCELLATION
  // ============================================================
  static Future<void> cancelCallNotification(int notificationId) async {
    try {
      await _localNotifications.cancel(notificationId);
      debugPrint('🔕 Call notification/ringtone cancelled: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to cancel call notification: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ============================================================
  // FOREGROUND GENERAL NOTIFICATION
  // ============================================================
  static Future<void> _showForegroundGeneralNotification(
      RemoteMessage message) async {
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
  // BACKGROUND CALL NOTIFICATION
  // ============================================================
  static Future<void> showBackgroundCallNotification(
      RemoteMessage message) async {
    debugPrint('🚨 [BACKGROUND HANDLER] CALL TRIGGERED! Data: ${message.data}');

    final FlutterLocalNotificationsPlugin localNotif =
        FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif
        .initialize(const InitializationSettings(android: androidInit));

    final androidPlugin = localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_callChannel);

    final data = message.data;

    final isVideoCall =
        data['isVideoCall'] == 'true' || data['isVideoCall'] == true;
    final callerName = data['callerName'] ?? 'Someone';

    final int notifId =
        data['callId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    final androidDetails = AndroidNotificationDetails(
      'call_channel_v9',
      'Incoming Calls',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
    );

    await localNotif.show(
      notifId,
      isVideoCall ? '📹 Incoming Video Call' : '📞 Incoming Call',
      isVideoCall
          ? '$callerName is video calling you...'
          : '$callerName is calling you...',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  // ============================================================
  // TOKEN MANAGEMENT (Updated with arrayUnion)
  // ============================================================
  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
    debugPrint('✅ Token saved to Firestore successfully!');
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
