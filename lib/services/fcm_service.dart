import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../utils/navigation_service.dart';
import '../screens/call_screen.dart';

// ============================================================
// ✅ FCM BACKGROUND HANDLER (অ্যাপ কিল থাকলে এটি রান হবে)
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

  // ✅ কল চ্যানেল (v9) - কাস্টম রিংটোন
  static const _callChannel = AndroidNotificationChannel(
    'call_channel_v9',
    'Incoming Calls',
    importance: Importance.max,
    playSound: true,
    sound:
        RawResourceAndroidNotificationSound('ringtone'), // ✅ কলের জন্য রিংটোন
    enableVibration: true,
  );

  // ✅ সাধারণ নোটিফিকেশন চ্যানেল (v5) - চ্যাট, ম্যাচ (ডিফল্ট সাউন্ড)
  static const _generalChannel = AndroidNotificationChannel(
    'general_channel_v5', // ✅ v5 করুন
    'General Notifications',
    importance: Importance.high,
    playSound: true,
    // sound: 'default', // ❌ এটি দিলে এরর আসে, তাই বাদ দিন। শুধু playSound:true দিলেই ডিফল্ট বাজবে।
  );

  // ============================================================
  // INITIALIZE
  // ============================================================
  static Future<void> initialize() async {
    if (_initialized) return;
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

      // ✅ অ্যাপ ওপেন থাকলে (Foreground)
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        debugPrint('🔔 Foreground message: ${message.data}');
        if (message.data['type'] == 'call') {
          NavigationService.handleNotificationTap(
            Map<String, dynamic>.from(message.data),
          );
        } else {
          _showForegroundGeneralNotification(message);
        }
      });

      // ✅ অ্যাপ ব্যাকগ্রাউন্ডে থাকলে নোটিফিকেশনে ক্লিক
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('🔔 Message opened app: ${message.data}');
        NavigationService.handleNotificationTap(
          Map<String, dynamic>.from(message.data),
        );
      });

      // ✅ অ্যাপ কিল থাকলে নোটিফিকেশন থেকে ওপেন
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 Initial message: ${initialMessage.data}');
        NavigationService.handleNotificationTap(
          Map<String, dynamic>.from(initialMessage.data),
        );
      }
    } catch (e) {
      debugPrint('❌ FCM init error: $e');
      _initialized = false;
    }
  }

  // ============================================================
  // ✅ FOREGROUND GENERAL NOTIFICATION (চ্যাট/ম্যাচ)
  // ============================================================
  static Future<void> _showForegroundGeneralNotification(
      RemoteMessage message) async {
    final data = message.data;
    final title = data['title'] ?? 'নতুন বার্তা';
    final body = data['body'] ?? 'আপনার জন্য নতুন নোটিফিকেশন আছে';

    final androidDetails = AndroidNotificationDetails(
      'general_channel_v5', // ✅ v5 করুন
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      // sound: 'default', // ❌ ডিলিট করুন
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
  // ✅ BACKGROUND GENERAL NOTIFICATION (চ্যাট/ম্যাচ)
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
      'general_channel_v5', // ✅ v5 করুন
      'General Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      // sound: 'default', // ❌ ডিলিট করুন
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
  // ✅ BACKGROUND CALL NOTIFICATION (Full Screen Intent)
  // ============================================================
  static Future<void> showBackgroundCallNotification(
      RemoteMessage message) async {
    debugPrint(
        '🚨🚨 [BACKGROUND HANDLER] CALL TRIGGERED! Data: ${message.data}');

    final FlutterLocalNotificationsPlugin localNotif =
        FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif
        .initialize(const InitializationSettings(android: androidInit));

    final androidPlugin = localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_callChannel);

    final data = message.data;
    final isVideoCall = data['isVideoCall'] == 'true';
    final callerName = data['callerName'] ?? 'Someone';

    final androidDetails = AndroidNotificationDetails(
      'call_channel_v9',
      'Incoming Calls',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
          'ringtone'), // ✅ কলের জন্য রিংটোন
      enableVibration: true,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
    );

    await localNotif.show(
      data['callId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      isVideoCall ? '📹 Incoming Video Call' : '📞 Incoming Call',
      '$callerName is calling you...',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================
  static Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmTokens': [token]
    }, SetOptions(merge: true));
    debugPrint('✅ Token saved to Firestore successfully!');
  }

  static Future<void> removeToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmTokens': FieldValue.delete()}, SetOptions(merge: true));
  }
}
