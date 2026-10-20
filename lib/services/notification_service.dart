import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// NOTIFICATION SERVICE
// In-App notification center এর সব কাজ
// ============================================================

class AppNotification {
  final String id;
  final String type; // like, match, message
  final String title;
  final String body;
  final String fromUid;
  final String fromName;
  final String fromPhotoUrl;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.fromUid,
    required this.fromName,
    required this.fromPhotoUrl,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: d['type'] ?? 'general',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      fromUid: d['fromUid'] ?? '',
      fromName: d['fromName'] ?? '',
      fromPhotoUrl: d['fromPhotoUrl'] ?? '',
      data: (d['data'] as Map<String, dynamic>?) ?? {},
      isRead: d['isRead'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String? get _uid => _auth.currentUser?.uid;

  // ============================================================
  // STREAM — সব notification (real-time)
  // ============================================================
  static Stream<List<AppNotification>> streamNotifications() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  // ============================================================
  // STREAM — Unread count (badge এর জন্য)
  // ============================================================
  static Stream<int> streamUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============================================================
  // MARK ONE AS READ
  // ============================================================
  static Future<void> markAsRead(String notifId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(notifId)
          .update({'isRead': true});
    } catch (_) {}
  }

  // ============================================================
  // MARK ALL AS READ
  // ============================================================
  static Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  // ============================================================
  // DELETE ONE
  // ============================================================
  static Future<void> delete(String notifId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(notifId)
          .delete();
    } catch (_) {}
  }

  // ============================================================
  // DELETE ALL
  // ============================================================
  static Future<void> deleteAll() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}
