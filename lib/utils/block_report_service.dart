import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// BLOCK / REPORT SERVICE
// ============================================================

class BlockReportService {
  // ============================================================
  // BLOCK USER
  // (শুধু নিজের doc-এ record — mutual নয়)
  // ============================================================

  static Future<bool> blockUser({
    required String myUid,
    required String theirUid,
  }) async {
    if (myUid == theirUid) return false;

    try {
      await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(myUid)
          .collection('blocked')
          .doc(theirUid)
          .set({
        'blockedUid': theirUid,
        'blockedAt': FieldValue.serverTimestamp(),
        'blockedBy': myUid,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // UNBLOCK USER
  // ============================================================

  static Future<bool> unblockUser({
    required String myUid,
    required String theirUid,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(myUid)
          .collection('blocked')
          .doc(theirUid)
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CHECK IF BLOCKED (by me)
  // ============================================================

  static Future<bool> isBlocked({
    required String myUid,
    required String theirUid,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(myUid)
          .collection('blocked')
          .doc(theirUid)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET ALL BLOCKED UIDs (আমি যাদের block করেছি)
  // ============================================================

  static Future<Set<String>> getBlockedUids(String myUid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('blockedUsers')
          .doc(myUid)
          .collection('blocked')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // REPORT USER
  // ============================================================

  static Future<bool> reportUser({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String details = '',
  }) async {
    if (reporterUid == reportedUid) return false;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}