import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// REFERRAL SERVICE
// Unique code generate + friend join + reward boost
// ============================================================

class ReferralService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ============================================================
  // GENERATE REFERRAL CODE from UID
  // ============================================================
  static String generateCodeFromUid(String uid) {
    if (uid.length < 8) return uid.toUpperCase();
    // UID এর প্রথম 6 characters (uppercase)
    final raw = uid.substring(0, 6).toUpperCase();
    // শুধু letter + number রাখি
    return raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  // ============================================================
  // ENSURE MY REFERRAL CODE EXISTS
  // Login এর পরে একবার কল করব
  // ============================================================
  static Future<String?> ensureMyCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      String? existing = data['referralCode'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;

      // Generate
      final code = generateCodeFromUid(uid);

      await _firestore.collection('users').doc(uid).set({
        'referralCode': code,
        'referralCount': data['referralCount'] ?? 0,
        'referralRewardsEarned': data['referralRewardsEarned'] ?? 0,
      }, SetOptions(merge: true));

      return code;
    } catch (e) {
      debugPrint('❌ ensureMyCode: $e');
      return null;
    }
  }

  // ============================================================
  // FIND USER BY REFERRAL CODE
  // ============================================================
  static Future<Map<String, dynamic>?> findUserByCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return null;

    try {
      final snap = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: clean)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      return {
        'uid': snap.docs.first.id,
        'name': snap.docs.first.data()['name'] ?? '',
        'photoUrl': snap.docs.first.data()['photoUrl'] ?? '',
      };
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // APPLY REFERRAL CODE
  // Registration এর পর ডাকব
  // ============================================================
  static Future<Map<String, dynamic>> applyReferralCode({
    required String newUserUid,
    required String code,
  }) async {
    final clean = code.trim().toUpperCase();

    try {
      // 1. Find referrer
      final referrer = await findUserByCode(clean);
      if (referrer == null) {
        return {'success': false, 'error': 'invalid_code'};
      }

      final referrerUid = referrer['uid'] as String;
      if (referrerUid == newUserUid) {
        return {'success': false, 'error': 'self_referral'};
      }

      // 2. Check if new user already used a code
      final newUserDoc = await _firestore
          .collection('users')
          .doc(newUserUid)
          .get();
      final newUserData = newUserDoc.data() ?? {};
      if (newUserData['referredBy'] != null) {
        return {'success': false, 'error': 'already_referred'};
      }

      // 3. Firestore batch — atomic write
      final batch = _firestore.batch();

      // Record on new user
      batch.set(_firestore.collection('users').doc(newUserUid), {
        'referredBy': referrerUid,
        'referredByCode': clean,
        'referredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update referrer's count
      batch.set(_firestore.collection('users').doc(referrerUid), {
        'referralCount': FieldValue.increment(1),
        'referralRewardsEarned': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Log referral
      batch.set(_firestore.collection('referrals').doc(), {
        'referrerUid': referrerUid,
        'referredUid': newUserUid,
        'code': clean,
        'rewardType': 'boost',
        'rewardHours': 24,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 4. Give 24h boost to referrer
      await _giveRewardBoost(referrerUid, hours: 24);

      return {'success': true, 'referrerName': referrer['name'] ?? ''};
    } catch (e) {
      debugPrint('❌ applyReferralCode: $e');
      return {'success': false, 'error': 'unknown'};
    }
  }

  // ============================================================
  // GIVE REWARD BOOST
  // ============================================================
  static Future<void> _giveRewardBoost(String uid, {required int hours}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final current = userDoc.data()?['boostedUntil'] as Timestamp?;

      DateTime baseTime = DateTime.now();
      if (current != null && current.toDate().isAfter(baseTime)) {
        baseTime = current.toDate(); // Already boosted → extend
      }

      final newUntil = baseTime.add(Duration(hours: hours));

      await _firestore.collection('users').doc(uid).update({
        'boostedUntil': Timestamp.fromDate(newUntil),
      });
    } catch (e) {
      debugPrint('❌ giveRewardBoost: $e');
    }
  }

  // ============================================================
  // GET MY REFERRAL STATS
  // ============================================================
  static Future<Map<String, dynamic>> getMyStats() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      return {
        'code': data['referralCode'] ?? '',
        'count': (data['referralCount'] as num?)?.toInt() ?? 0,
        'rewards': (data['referralRewardsEarned'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  // ============================================================
  // GET REFERRAL HISTORY
  // ============================================================
  static Future<List<Map<String, dynamic>>> getMyReferrals() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      final snap = await _firestore
          .collection('referrals')
          .where('referrerUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> list = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        final referredUid = data['referredUid'] as String? ?? '';

        // Get referred user info
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(referredUid)
              .get();
          if (userDoc.exists) {
            final ud = userDoc.data() ?? {};
            list.add({
              'uid': referredUid,
              'name': ud['name'] ?? 'User',
              'photoUrl': ud['photoUrl'] ?? '',
              'createdAt': data['createdAt'],
            });
          }
        } catch (_) {}
      }

      return list;
    } catch (e) {
      return [];
    }
  }
}
