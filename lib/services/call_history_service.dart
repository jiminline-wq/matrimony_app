import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/call_history_entry.dart';

// ============================================================
// CALL HISTORY SERVICE
// "calls" collection ব্যবহার করে history দেখায়
// ============================================================

class CallHistoryService {
  static final _firestore = FirebaseFirestore.instance;

  static String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // UPDATE DURATION WHEN CALL ENDS
  // ============================================================
  static Future<void> updateDuration(String callId, int duration) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'duration': duration,
        'endedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Duration saved: ${duration}s');
    } catch (e) {
      debugPrint('❌ Update duration failed: $e');
    }
  }

  // ============================================================
  // STREAM ALL MY CALLS (as caller OR receiver)
  // ============================================================
  static Stream<List<CallHistoryEntry>> streamHistory() {
    final uid = _myUid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('calls')
        .where('users', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => CallHistoryEntry.fromDoc(doc))
              .where(
                (e) =>
                    e.status == 'ended' ||
                    e.status == 'rejected' ||
                    e.status == 'missed',
              )
              .toList();
        });
  }

  // ============================================================
  // STREAM MISSED COUNT (for badge)
  // ============================================================
  static Stream<int> streamMissedCount() {
    final uid = _myUid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('calls')
        .where('users', arrayContains: uid)
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'missed')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============================================================
  // DELETE ONE ENTRY
  // ============================================================
  static Future<void> deleteEntry(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).delete();
      debugPrint('✅ Call entry deleted');
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
    }
  }

  // ============================================================
  // CLEAR ALL (only my calls)
  // ============================================================
  static Future<void> clearAll() async {
    final uid = _myUid;
    if (uid == null) return;

    try {
      final snap = await _firestore
          .collection('calls')
          .where('users', arrayContains: uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('✅ All call history cleared');
    } catch (e) {
      debugPrint('❌ Clear all failed: $e');
    }
  }
}
