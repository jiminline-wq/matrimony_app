import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// SHORTLIST SERVICE
// ============================================================

class ShortlistService {
  // ============================================================
  // SAVE USER
  // ============================================================

  static Future<bool> saveUser({
    required String myUid,
    required String theirUid,
  }) async {
    if (myUid == theirUid) return false;

    try {
      await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(myUid)
          .collection('saved')
          .doc(theirUid)
          .set({
        'savedUid': theirUid,
        'savedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // REMOVE USER
  // ============================================================

  static Future<bool> removeUser({
    required String myUid,
    required String theirUid,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(myUid)
          .collection('saved')
          .doc(theirUid)
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // CHECK IF SAVED
  // ============================================================

  static Future<bool> isSaved({
    required String myUid,
    required String theirUid,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(myUid)
          .collection('saved')
          .doc(theirUid)
          .get();

      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET SAVED UIDs
  // ============================================================

  static Future<Set<String>> getSavedUids(String myUid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(myUid)
          .collection('saved')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // GET SAVED COUNT
  // ============================================================

  static Future<int> getSavedCount(String myUid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(myUid)
          .collection('saved')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}