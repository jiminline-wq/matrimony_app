import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// LIKE SERVICE
// ============================================================

class LikeService {
  // ============================================================
  // LIKE USER — with automatic match creation
  // ============================================================
  static Future<bool> likeUser({
    required String myUid,
    required String theirUid,
  }) async {
    // ✅ Better diagnostics
    if (myUid.trim().isEmpty) {
      debugPrint('❌ likeUser skipped — myUid empty');
      return false;
    }
    if (theirUid.trim().isEmpty) {
      debugPrint('❌ likeUser skipped — theirUid empty');
      return false;
    }
    if (myUid == theirUid) {
      debugPrint('❌ likeUser skipped — cannot like yourself');
      return false;
    }
    final firestore = FirebaseFirestore.instance;
    final now = FieldValue.serverTimestamp();

    try {
      debugPrint('💗 Liking $theirUid from $myUid...');

      // 1. Save my like (outgoing)
      await firestore
          .collection('likes')
          .doc(myUid)
          .collection('liked')
          .doc(theirUid)
          .set({'likedUid': theirUid, 'likedAt': now});
      debugPrint('✅ liked saved');

      // 2. Save to their "likesReceived" (incoming)
      await firestore
          .collection('likesReceived')
          .doc(theirUid)
          .collection('likedBy')
          .doc(myUid)
          .set({'likedByUid': myUid, 'likedAt': now});
      debugPrint('✅ likedBy saved');

      // ============================================================
      // 3. ✅ CHECK FOR MUTUAL — did they already like me?
      // ============================================================
      final theirLikeOfMe = await firestore
          .collection('likes')
          .doc(theirUid)
          .collection('liked')
          .doc(myUid)
          .get();

      if (!theirLikeOfMe.exists) {
        debugPrint('⏳ Not mutual yet');
        return true; // like saved, but no match
      }

      debugPrint('🎉 MUTUAL LIKE! Creating match...');

      // ============================================================
      // 4. ✅ CREATE MATCH
      // ============================================================
      // ✅ sort uid list so both sides get same matchId
      final ids = [myUid, theirUid]..sort();
      final matchId = '${ids[0]}_${ids[1]}';

      // ✅ fetch both profiles to embed in match doc
      final myProfileDoc = await firestore.collection('users').doc(myUid).get();
      final theirProfileDoc =
          await firestore.collection('users').doc(theirUid).get();

      final myData = myProfileDoc.data() ?? {};
      final theirData = theirProfileDoc.data() ?? {};

      // ✅ build minimal user maps for matches_tab
      final myUserMap = <String, dynamic>{
        'uid': myUid,
        'name': myData['name'] ?? 'User',
        'photoUrl': myData['photoUrl'] ?? myData['photo'] ?? '',
        'age': myData['age']?.toString() ?? '',
        'district': myData['district'] ?? '',
        'isVerified': myData['isVerified'] ?? false,
      };

      final theirUserMap = <String, dynamic>{
        'uid': theirUid,
        'name': theirData['name'] ?? 'User',
        'photoUrl': theirData['photoUrl'] ?? theirData['photo'] ?? '',
        'age': theirData['age']?.toString() ?? '',
        'district': theirData['district'] ?? '',
        'isVerified': theirData['isVerified'] ?? false,
      };

      await firestore.collection('matches').doc(matchId).set({
        'users': [myUid, theirUid],
        'user1': myUserMap,
        'user2': theirUserMap,
        'matchedAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Match created: $matchId');

      return true;
    } catch (e) {
      debugPrint('❌ likeUser failed: $e');
      return false;
    }
  }

  // ============================================================
  // UNLIKE USER
  // ============================================================
  static Future<bool> unlikeUser({
    required String myUid,
    required String theirUid,
  }) async {
    // ✅ Guard
    if (myUid.trim().isEmpty || theirUid.trim().isEmpty) {
      debugPrint('⚠️ unlikeUser skipped — empty uid');
      return false;
    }

    try {
      debugPrint('💔 Unliking $theirUid...');

      await FirebaseFirestore.instance
          .collection('likes')
          .doc(myUid)
          .collection('liked')
          .doc(theirUid)
          .delete();

      await FirebaseFirestore.instance
          .collection('likesReceived')
          .doc(theirUid)
          .collection('likedBy')
          .doc(myUid)
          .delete();

      debugPrint('✅ Unliked');
      return true;
    } catch (e) {
      debugPrint('❌ unlikeUser failed: $e');
      return false;
    }
  }

  // ============================================================
  // HAVE I LIKED
  // ============================================================
  static Future<bool> haveILiked({
    required String myUid,
    required String theirUid,
  }) async {
    // ✅ Guard — empty uid হলে skip
    if (myUid.trim().isEmpty || theirUid.trim().isEmpty) {
      debugPrint('⚠️ haveILiked skipped — empty uid');
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('likes')
          .doc(myUid)
          .collection('liked')
          .doc(theirUid)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('❌ haveILiked failed: $e');
      return false;
    }
  }

  // ============================================================
  // WHO LIKED ME
  // ============================================================
  static Future<List<Map<String, dynamic>>> getWhoLikedMe(String myUid) async {
    if (myUid.trim().isEmpty) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('likesReceived')
          .doc(myUid)
          .collection('likedBy')
          .orderBy('likedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final likerUid = data['likedByUid'] as String? ?? '';
        if (likerUid.isEmpty) continue;

        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(likerUid)
              .get();

          if (profileDoc.exists) {
            result.add({
              'uid': likerUid,
              'profile': profileDoc.data(),
              'likedAt': data['likedAt'],
            });
          }
        } catch (e) {
          debugPrint('⚠️ Skipping $likerUid: $e');
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ getWhoLikedMe failed: $e');
      return [];
    }
  }

  // ============================================================
  // GET LIKES COUNT
  // ============================================================
  static Future<int> getLikesCount(String myUid) async {
    if (myUid.trim().isEmpty) return 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('likesReceived')
          .doc(myUid)
          .collection('likedBy')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ getLikesCount failed: $e');
      return 0;
    }
  }
}
