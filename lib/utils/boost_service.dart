import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ debugPrint-এর জন্য

// ============================================================
// BOOST SERVICE
// ============================================================

class BoostService {
  // ✅ Default durations
  static const int boostDurationHours = 24; // Premium/Manual
  static const int adBoostDurationHours = 12; // Rewarded Ad

  // ============================================================
  // ACTIVATE BOOST — 24h (future premium use)
  // ============================================================
  static Future<bool> activateBoost(String uid) async {
    if (uid.trim().isEmpty) return false;

    try {
      final now = DateTime.now();
      final boostedUntil = now.add(
        const Duration(hours: boostDurationHours),
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'boostedAt': FieldValue.serverTimestamp(),
        'boostedUntil': Timestamp.fromDate(boostedUntil),
        'boostDuration': boostDurationHours,
      });

      // ✅ Boost history
      await FirebaseFirestore.instance.collection('boostHistory').add({
        'uid': uid,
        'boostedAt': FieldValue.serverTimestamp(),
        'boostedUntil': Timestamp.fromDate(boostedUntil),
        'durationHours': boostDurationHours,
        'source': 'direct', // ✅ source track
      });

      debugPrint('✅ [Boost] 24h boost activated for $uid');
      return true;
    } catch (e) {
      debugPrint('❌ activateBoost failed: $e');
      return false;
    }
  }

  // ============================================================
  // BOOST FOR 12 HOURS (via Rewarded Ad) — PRIMARY METHOD
  // ============================================================
  static Future<bool> boostFor12Hours(String uid) async {
    if (uid.trim().isEmpty) return false;

    try {
      final firestore = FirebaseFirestore.instance;
      final now = DateTime.now();
      final until = now.add(const Duration(hours: adBoostDurationHours));

      await firestore.collection('users').doc(uid).update({
        'boostedUntil': Timestamp.fromDate(until),
        'boostedAt': FieldValue.serverTimestamp(),
        'boostDuration': adBoostDurationHours,
      });

      // ✅ Boost history (Analytics-এর জন্য)
      await firestore.collection('boostHistory').add({
        'uid': uid,
        'boostedAt': FieldValue.serverTimestamp(),
        'boostedUntil': Timestamp.fromDate(until),
        'durationHours': adBoostDurationHours,
        'source': 'rewarded_ad', // ✅ source track
      });

      debugPrint('✅ [Boost] User $uid boosted for 12h until $until');
      return true;
    } catch (e) {
      debugPrint('❌ boostFor12Hours failed: $e');
      return false;
    }
  }

  // ============================================================
  // CHECK IF BOOST ACTIVE
  // ============================================================
  static bool isBoostActive(dynamic boostedUntil) {
    if (boostedUntil == null) return false;

    try {
      final until = (boostedUntil as Timestamp).toDate();
      return until.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // GET REMAINING TIME
  // ============================================================
  static Duration? getRemainingTime(dynamic boostedUntil) {
    if (boostedUntil == null) return null;

    try {
      final until = (boostedUntil as Timestamp).toDate();
      final remaining = until.difference(DateTime.now());
      if (remaining.isNegative) return null;
      return remaining;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET BOOSTED USERS (sorted by boostedUntil desc)
  // ============================================================
  static Future<Set<String>> getBoostedUids() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('boostedUntil', isGreaterThan: now)
          .orderBy('boostedUntil', descending: true)
          .limit(30)
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('❌ getBoostedUids failed: $e');
      return {};
    }
  }
}
