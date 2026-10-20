import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import '../screens/home_screen.dart';
import '../screens/who_liked_me_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/call_screen.dart';

// ============================================================
// NAVIGATION SERVICE
// ============================================================

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Map<String, dynamic>? _pendingNotification;

  static void setPending(Map<String, dynamic> data) {
    _pendingNotification = data;
  }

  static void savePending(Map<String, dynamic> data) {
    setPending(data);
  }

  static Map<String, dynamic>? consumePending() {
    final p = _pendingNotification;
    _pendingNotification = null;
    return p;
  }

  // ============================================================
  // MAIN HANDLER (সব নোটিফিকেশনের জন্য)
  // ============================================================
  static Future<void> handleNotificationTap(
    Map<String, dynamic> data, {
    bool isBangla = true,
  }) async {
    final type = data['type'];
    if (type == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      setPending(data);
      debugPrint('📌 Navigation pending (navigator not ready): $data');
      return;
    }

    debugPrint('🚀 Navigating for type: $type');

    switch (type) {
      case 'like':
        nav.push(
          MaterialPageRoute(
            builder: (_) => WhoLikedMeScreen(isBangla: isBangla),
          ),
        );
        break;

      case 'match':
        nav.push(
          MaterialPageRoute(
            builder: (_) => HomeScreen(isBangla: isBangla, initialIndex: 3),
          ),
        );
        break;

      case 'message':
        final otherUid = data['uid']?.toString();
        if (otherUid != null && otherUid.isNotEmpty) {
          await _openChat(nav, otherUid, isBangla);
        } else {
          debugPrint('⚠️ No uid in message notification — opening chat list');
          nav.push(
            MaterialPageRoute(
              builder: (_) => ChatListScreen(isBangla: isBangla),
            ),
          );
        }
        break;

      case 'call':
        _openCall(nav, data);
        break;

      default:
        debugPrint('⚠️ Unknown notification type: $type');
    }
  }

  // ============================================================
  // OPEN CALL SCREEN
  // ============================================================
  static void _openCall(NavigatorState nav, Map<String, dynamic> data) {
    try {
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
      debugPrint('✅ CallScreen opened from notification');
    } catch (e) {
      debugPrint('❌ Failed to open call screen: $e');
    }
  }

  // ============================================================
  // OPEN CHAT SCREEN
  // ============================================================
  static Future<void> _openChat(
    NavigatorState nav,
    String otherUid,
    bool isBangla,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get();

      if (!doc.exists) {
        debugPrint('❌ User not found: $otherUid — opening chat list');
        nav.push(
          MaterialPageRoute(builder: (_) => ChatListScreen(isBangla: isBangla)),
        );
        return;
      }

      final profile = UserProfile.fromMap(doc.data()!, docId: doc.id);

      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            isBangla: isBangla,
            otherUserId: profile.uid,
            otherUserName: profile.name,
            otherUserPhoto: profile.photoUrl,
          ),
        ),
      );

      debugPrint('✅ Chat opened with ${profile.name}');
    } catch (e) {
      debugPrint('❌ Failed to open chat: $e — opening chat list');
      nav.push(
        MaterialPageRoute(builder: (_) => ChatListScreen(isBangla: isBangla)),
      );
    }
  }
}
