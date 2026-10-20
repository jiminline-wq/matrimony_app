import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// CALL SERVICE
// Firestore-based call signaling
// ============================================================

class CallService {
  static final _firestore = FirebaseFirestore.instance;
  static final _callsRef = _firestore.collection('calls');

  // ---------- Call status ----------
  static const String statusRinging = 'ringing';
  static const String statusAccepted = 'accepted';
  static const String statusRejected = 'rejected';
  static const String statusEnded = 'ended';
  static const String statusMissed = 'missed';
  static const String statusCancelled = 'cancelled';

  // ---------- Ring timeout ----------
  static const Duration ringTimeout = Duration(seconds: 45);

  // ============================================================
  // GET CURRENT USER UID
  // ============================================================
  static String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================
  // CHECK — Already in an active call? (with age guard)
  // ============================================================
  static Future<bool> hasActiveCall() async {
    final myUid = _myUid;
    if (myUid == null) return false;

    try {
      final snap = await _callsRef
          .where('users', arrayContains: myUid)
          .where('status', whereIn: [statusRinging, statusAccepted])
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      if (snap.docs.isEmpty) return false;

      final now = DateTime.now();
      const maxRingingAge = Duration(seconds: 90);
      const maxAcceptedAge = Duration(minutes: 30);

      final batch = _firestore.batch();
      bool hasStale = false;
      bool activeFound = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt == null) {
          activeFound = true;
          continue;
        }

        final age = now.difference(createdAt);

        if (status == statusRinging && age < maxRingingAge) {
          activeFound = true;
        } else if (status == statusAccepted && age < maxAcceptedAge) {
          activeFound = true;
        } else {
          batch.update(doc.reference, {
            'status': statusMissed,
            'updatedAt': FieldValue.serverTimestamp(),
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': 'stale-cleanup',
          });
          hasStale = true;
        }
      }

      if (hasStale) {
        await batch.commit();
      }

      return activeFound;
    } catch (e) {
      debugPrint('❌ hasActiveCall failed: $e');
      return false;
    }
  }

  // ============================================================
  // START CALL (Caller side)
  // ============================================================
  static Future<String?> startCall({
    required String channelName,
    required String receiverId,
    required String receiverName,
    required String receiverPhoto,
    required bool isVideoCall,
  }) async {
    try {
      final myUid = _myUid;
      if (myUid == null) return null;

      if (myUid == receiverId) {
        debugPrint('❌ Cannot call yourself');
        return null;
      }

      if (await hasActiveCall()) {
        debugPrint('⚠️ Already in an active call');
        return null;
      }

      final myDoc = await _firestore.collection('users').doc(myUid).get();
      final myData = myDoc.data() ?? {};
      final myName = myData['name'] ?? 'User';
      final myPhoto = myData['photoUrl'] ?? myData['photo'] ?? '';

      final docRef = await _callsRef.add({
        'users': [myUid, receiverId],
        'channelName': channelName,
        'callerId': myUid,
        'callerName': myName,
        'callerPhoto': myPhoto,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'receiverPhoto': receiverPhoto,
        'isVideoCall': isVideoCall,
        'status': statusRinging,
        'duration': 0,
        'endedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📞 Call started: ${docRef.id}');
      _scheduleMissedCall(docRef.id);

      return docRef.id;
    } catch (e) {
      debugPrint('❌ startCall failed: $e');
      return null;
    }
  }

  // ============================================================
  // AUTO-MISSED (caller side fires this)
  // ============================================================
  static void _scheduleMissedCall(String callId) {
    Future.delayed(ringTimeout, () async {
      try {
        final doc = await _callsRef.doc(callId).get();
        if (!doc.exists) return;
        final data = doc.data();
        if (data == null) return;

        if (data['status'] == statusRinging) {
          await _callsRef.doc(callId).update({
            'status': statusMissed,
            'updatedAt': FieldValue.serverTimestamp(),
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': 'timeout',
          });
          debugPrint('📭 Call auto-missed: $callId');
        }
      } catch (e) {
        debugPrint('❌ _scheduleMissedCall failed: $e');
      }
    });
  }

  // ============================================================
  // ACCEPT CALL (Receiver)
  // ============================================================
  static Future<void> acceptCall(String callId) async {
    try {
      await _callsRef.doc(callId).update({
        'status': statusAccepted,
        'updatedAt': FieldValue.serverTimestamp(),
        'answeredAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Call accepted: $callId');
    } catch (e) {
      debugPrint('❌ acceptCall failed: $e');
    }
  }

  // ============================================================
  // REJECT CALL (Receiver — explicit decline)
  // ============================================================
  static Future<void> rejectCall(String callId) async {
    try {
      await _callsRef.doc(callId).update({
        'status': statusRejected,
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': _myUid,
      });
      debugPrint('❌ Call rejected: $callId');
    } catch (e) {
      debugPrint('❌ rejectCall failed: $e');
    }
  }

  // ============================================================
  // CANCEL CALL (Caller hung up before receiver answered)
  // ============================================================
  static Future<void> cancelCall(String callId) async {
    try {
      await _callsRef.doc(callId).update({
        'status': statusCancelled,
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': _myUid,
      });
      debugPrint('🚫 Call cancelled: $callId');
    } catch (e) {
      debugPrint('❌ cancelCall failed: $e');
    }
  }

  // ============================================================
  // END CALL (either side — after both joined)
  // ============================================================
  static Future<void> endCall(String callId, {int? durationSeconds}) async {
    try {
      final Map<String, dynamic> data = {
        'status': statusEnded,
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': _myUid,
      };

      if (durationSeconds != null && durationSeconds > 0) {
        data['duration'] = durationSeconds;
      }

      await _callsRef.doc(callId).update(data);
      debugPrint('👋 Call ended: $callId (duration: ${durationSeconds}s)');
    } catch (e) {
      debugPrint('❌ endCall failed: $e');
    }
  }

  // ============================================================
  // MISSED CALL
  // ============================================================
  static Future<void> missedCall(String callId) async {
    try {
      await _callsRef.doc(callId).update({
        'status': statusMissed,
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': 'timeout',
      });
      debugPrint('📭 Call marked as missed: $callId');
    } catch (e) {
      debugPrint('❌ missedCall failed: $e');
    }
  }

  // ============================================================
  // GET SINGLE CALL
  // ============================================================
  static Future<DocumentSnapshot?> getCall(String callId) async {
    try {
      final doc = await _callsRef.doc(callId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      debugPrint('❌ getCall failed: $e');
      return null;
    }
  }

  // ============================================================
  // GET CALL HISTORY
  // ============================================================
  static Future<List<QueryDocumentSnapshot>> getCallHistory({
    int limit = 50,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return [];

    try {
      final snap = await _callsRef
          .where('users', arrayContains: myUid)
          .where('status', whereIn: [
            statusEnded,
            statusMissed,
            statusRejected,
            statusCancelled,
          ])
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snap.docs;
    } catch (e) {
      debugPrint('❌ getCallHistory failed: $e');
      return [];
    }
  }

  // ============================================================
  // CLEANUP STALE RINGING CALLS
  // ============================================================
  static Future<int> cleanupStaleCalls() async {
    final myUid = _myUid;
    if (myUid == null) return 0;

    try {
      final cutoff = DateTime.now().subtract(ringTimeout * 2);

      final snap = await _callsRef
          .where('users', arrayContains: myUid)
          .where('status', isEqualTo: statusRinging)
          .get();

      int count = 0;
      final batch = _firestore.batch();

      for (final doc in snap.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && createdAt.isBefore(cutoff)) {
          batch.update(doc.reference, {
            'status': statusMissed,
            'updatedAt': FieldValue.serverTimestamp(),
            'endedAt': FieldValue.serverTimestamp(),
            'endedBy': 'cleanup',
          });
          count++;
        }
      }

      if (count > 0) await batch.commit();
      debugPrint('🧹 Cleaned up $count stale calls');
      return count;
    } catch (e) {
      debugPrint('❌ cleanupStaleCalls failed: $e');
      return 0;
    }
  }

  // ============================================================
  // STREAMS
  // ============================================================
  static Stream<QuerySnapshot> incomingCallStream() {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();

    return _callsRef
        .where('receiverId', isEqualTo: myUid)
        .where('status', isEqualTo: statusRinging)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots();
  }

  static Stream<DocumentSnapshot> callStream(String callId) {
    return _callsRef.doc(callId).snapshots();
  }
}
