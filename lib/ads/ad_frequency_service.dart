// ============================================================
// AD FREQUENCY SERVICE
// Central daily-limit tracker for all ad-gated actions.
//
// Firestore layout:
//   ad_usage/{uid}
//     actions: {
//       boost:   { count, lastDate, lastAt },
//       save:    { count, lastDate, lastAt },
//       like:    { count, lastDate, lastAt },
//       ...
//     }
//
// ⚠️ Server-time anchor দিয়ে date হিসাব — device clock বদলে দিলে
//    কাজ করবে না। Fallback: device time (fail-open)।
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdFrequencyService {
  static final _firestore = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // ACTION NAMES
  // ------------------------------------------------------------
  static const String actionBoost = 'boost';
  static const String actionSave = 'save';
  static const String actionLike = 'like';
  static const String actionProfileView = 'profile_view';
  static const String actionMessage = 'message';
  static const String actionRewardedUnlock = 'rewarded_unlock';
  static const String actionFilterApply = 'filter_apply';

  // ------------------------------------------------------------
  // DAILY LIMITS
  // ------------------------------------------------------------
  static const Map<String, int> _dailyLimits = {
    actionBoost: 3,
    actionSave: 10,
    actionLike: 60,
    actionProfileView: 30,
    actionMessage: 30,
    actionRewardedUnlock: 5,
    actionFilterApply: 10,
  };

  /// Backward-compat getter (BoostScreen uses this)
  static int get maxBoostsPerDay => _dailyLimits[actionBoost]!;

  // ============================================================
  // BACKWARD-COMPAT — Boost API
  // ============================================================
  static Future<BoostEligibility> canBoostToday() async {
    final r = await canDoAction(actionBoost);
    return BoostEligibility(
      canBoost: r.allowed || r.isPremium,
      reason: r.reason,
      usedToday: r.usedToday,
      remaining: r.remaining,
    );
  }

  static Future<void> recordBoostUsage() => recordActionUsage(actionBoost);

  // ============================================================
  // GENERIC API
  // ============================================================
  static Future<ActionEligibility> canDoAction(String action) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final limit = _dailyLimits[action];

    if (myUid == null) {
      return ActionEligibility(
        allowed: false,
        isPremium: false,
        reason: 'not_logged_in',
        usedToday: 0,
        remaining: 0,
        dailyLimit: limit ?? 0,
      );
    }

    if (limit == null) {
      // Unknown action — fail-open
      debugPrint('⚠️ Unknown action: $action');
      return ActionEligibility(
        allowed: true,
        isPremium: false,
        reason: null,
        usedToday: 0,
        remaining: 0,
        dailyLimit: 0,
      );
    }

    try {
      // ✅ Premium bypass
      if (await _isPremium(myUid)) {
        return ActionEligibility(
          allowed: true,
          isPremium: true,
          reason: 'premium_user',
          usedToday: 0,
          remaining: limit,
          dailyLimit: limit,
        );
      }

      final today = await _serverToday();
      final doc = await _firestore.collection('ad_usage').doc(myUid).get();

      if (!doc.exists) {
        return ActionEligibility(
          allowed: true,
          isPremium: false,
          reason: null,
          usedToday: 0,
          remaining: limit,
          dailyLimit: limit,
        );
      }

      final actions = (doc.data()?['actions'] as Map?) ?? {};
      final entry = (actions[action] as Map?) ?? {};
      final lastDate = (entry['lastDate'] as String?) ?? '';
      final count = (entry['count'] as num?)?.toInt() ?? 0;

      if (lastDate != today) {
        return ActionEligibility(
          allowed: true,
          isPremium: false,
          reason: null,
          usedToday: 0,
          remaining: limit,
          dailyLimit: limit,
        );
      }

      final remaining = (limit - count).clamp(0, limit);
      return ActionEligibility(
        allowed: remaining > 0,
        isPremium: false,
        reason: remaining > 0 ? null : 'daily_limit_reached',
        usedToday: count,
        remaining: remaining,
        dailyLimit: limit,
      );
    } catch (e) {
      debugPrint('❌ canDoAction($action) error: $e');
      // Fail-open — allow on error
      return ActionEligibility(
        allowed: true,
        isPremium: false,
        reason: null,
        usedToday: 0,
        remaining: limit,
        dailyLimit: limit,
      );
    }
  }

  static Future<void> recordActionUsage(String action) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    if (!_dailyLimits.containsKey(action)) {
      debugPrint('⚠️ Cannot record unknown action: $action');
      return;
    }

    try {
      final today = await _serverToday();
      final docRef = _firestore.collection('ad_usage').doc(myUid);
      final doc = await docRef.get();

      final actions = (doc.data()?['actions'] as Map?) ?? {};
      final entry = (actions[action] as Map?) ?? {};
      final lastDate = (entry['lastDate'] as String?) ?? '';

      if (doc.exists && lastDate == today) {
        // ✅ Same day — atomic increment (race-safe)
        await docRef.update({
          'actions.$action.count': FieldValue.increment(1),
          'actions.$action.lastDate': today,
          'actions.$action.lastAt': FieldValue.serverTimestamp(),
        });
      } else {
        // New day OR first use — reset counter
        await docRef.set({
          'actions': {
            action: {
              'count': 1,
              'lastDate': today,
              'lastAt': FieldValue.serverTimestamp(),
            }
          }
        }, SetOptions(merge: true));
      }

      debugPrint('✅ [AdFrequency] $action usage recorded');
    } catch (e) {
      debugPrint('❌ recordActionUsage($action) error: $e');
    }
  }

  // ============================================================
  // PREMIUM CHECK
  // ============================================================
  static Future<bool> _isPremium(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final until = doc.data()?['premiumUntil'] as Timestamp?;
      if (until == null) return false;
      return until.toDate().isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // SERVER DATE — device-clock resistant
  // ============================================================
  static String? _cachedServerDate;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 10);

  static Future<String> _serverToday() async {
    if (_cachedServerDate != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cachedServerDate!;
    }

    try {
      // 📌 Setup required (Firebase Console-এ একবার):
      //   Collection: _server_heartbeat
      //   Document:  now
      //   Field:     ts  (type: Timestamp)
      //
      //   এই document-টার ts field প্রতিদিন update করতে হবে (manual
      //   বা Cloud Function দিয়ে)। এটা ছাড়া device time-এ fallback করবে।
      final snap =
          await _firestore.collection('_server_heartbeat').doc('now').get();

      final ts = snap.data()?['ts'] as Timestamp?;
      if (ts != null) {
        final d = ts.toDate();
        final s = _formatDate(d);
        _cachedServerDate = s;
        _cacheTime = DateTime.now();
        return s;
      }
    } catch (e) {
      debugPrint('⚠️ Server time fetch failed, using device time: $e');
    }

    return _formatDate(DateTime.now());
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ============================================================
// RESULT MODELS
// ============================================================

/// Backward-compatible with BoostScreen.
class BoostEligibility {
  final bool canBoost;
  final String? reason;
  final int usedToday;
  final int remaining;

  BoostEligibility({
    required this.canBoost,
    required this.reason,
    required this.usedToday,
    required this.remaining,
  });
}

/// Generic result — for save, like, view, message, etc.
class ActionEligibility {
  final bool allowed;
  final bool isPremium;
  final String? reason;
  final int usedToday;
  final int remaining;
  final int dailyLimit;

  ActionEligibility({
    required this.allowed,
    required this.isPremium,
    required this.reason,
    required this.usedToday,
    required this.remaining,
    required this.dailyLimit,
  });
}
