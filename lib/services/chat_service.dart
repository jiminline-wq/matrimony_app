import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// CHAT SERVICE — Delete + Archive
// ============================================================

class ChatService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ============================================================
  // ARCHIVE CHAT
  // ============================================================
  static Future<bool> archiveChat(String chatId, bool archive) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ archiveChat: no uid');
      return false;
    }

    try {
      debugPrint('📦 Archiving chat: $chatId → $archive (user: $uid)');

      await _firestore.collection('chats').doc(chatId).set({
        'archivedFor.$uid': archive,
      }, SetOptions(merge: true));

      debugPrint('✅ Archive write success');
      return true;
    } catch (e) {
      debugPrint('❌ Archive failed: $e');
      return false;
    }
  }

  // ============================================================
  // DELETE CHAT (soft delete for this user only)
  // ============================================================
  static Future<bool> deleteChat(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _firestore.collection('chats').doc(chatId).set({
        'deletedFor.$uid': true,
        'deletedAt.$uid': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
      return false;
    }
  }

  // ============================================================
  // RESTORE CHAT (undo delete/archive)
  // ============================================================
  static Future<bool> restoreChat(String chatId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      await _firestore.collection('chats').doc(chatId).set({
        'deletedFor.$uid': false,
        'archivedFor.$uid': false,
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logCallMessage({
    required String senderId,
    required String receiverId,
    required bool isVideo,
    required String status, // 'missed', 'rejected', 'ended'
    int? duration, // সেকেন্ডে
  }) async {
    final ids = [senderId, receiverId]..sort();
    final chatId = '${ids[0]}_${ids[1]}';
    final chatRef = _firestore.collection('chats').doc(chatId);

    String text = '';
    if (status == 'missed') {
      text = isVideo ? '📹 মিসড ভিডিও কল' : '📞 মিসড ভয়েস কল';
    } else if (status == 'rejected') {
      text = isVideo ? '📹 বাতিল করা ভিডিও কল' : '📞 বাতিল করা ভয়েস কল';
    } else if (status == 'ended') {
      final mins = (duration ?? 0) ~/ 60;
      final secs = (duration ?? 0) % 60;
      final timeStr = mins > 0 ? '$mins মিনিট $secs সেকেন্ড' : '$secs সেকেন্ড';
      text = isVideo ? '📹 ভিডিও কল · $timeStr' : '📞 ভয়েস কল · $timeStr';
    } else {
      return; // অন্যান্য স্টেটাস ইগনোর করুন
    }

    final msgRef = chatRef.collection('messages').doc();

    try {
      await _firestore.runTransaction((tx) async {
        tx.set(msgRef, {
          'senderId': senderId,
          'receiverId': receiverId,
          'type': 'call', // ✅ নতুন টাইপ 'call'
          'text': text,
          'callStatus': status,
          'isVideo': isVideo,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        tx.set(
            chatRef,
            {
              'lastMessage': text,
              'lastMessageTime': FieldValue.serverTimestamp(),
              'lastSenderId': senderId,
              'users': [senderId, receiverId],
              'unreadCounts.$receiverId': FieldValue.increment(1),
              'deletedFor.$senderId': false,
              'deletedFor.$receiverId': false,
              'archivedFor.$senderId': false,
              'archivedFor.$receiverId': false,
            },
            SetOptions(merge: true));
      });
      debugPrint('✅ Call log saved to chat');
    } catch (e) {
      debugPrint('❌ Failed to save call log: $e');
    }
  }
}
