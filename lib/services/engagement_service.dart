import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EngagementService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ✅ এই ফাংশনটি অ্যাপ ওপেন হওয়ার সাথে সাথে কল করতে হবে
  static Future<Map<String, dynamic>?> checkAndUpdateStreak() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final doc = await userRef.get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final now = DateTime.now();

      // আজকের তারিখ (Time ছাড়া শুধু Date)
      final today = DateTime(now.year, now.month, now.day);

      // শেষ লগইনের তারিখ
      final Timestamp? lastLoginTs = data['lastLoginDate'];
      final DateTime? lastLogin = lastLoginTs?.toDate();
      final DateTime? lastLoginDate = lastLogin != null
          ? DateTime(lastLogin.year, lastLogin.month, lastLogin.day)
          : null;

      int currentStreak = (data['loginStreak'] ?? 0) as int;
      int lastRewardClaimed = (data['lastRewardClaimedStreak'] ?? 0) as int;
      bool isNewDay = false;

      // ✅ লজিক: স্ট্রিক চেক করা
      if (lastLoginDate == null) {
        // প্রথমবার লগইন
        currentStreak = 1;
        isNewDay = true;
      } else {
        final difference = today.difference(lastLoginDate).inDays;

        if (difference == 1) {
          // গতকাল লগইন করেছে → স্ট্রিক বাড়বে
          currentStreak++;
          isNewDay = true;
        } else if (difference > 1) {
          // একদিনের বেশি গ্যাপ → স্ট্রিক রিসেট
          currentStreak = 1;
          isNewDay = true;
        }
        // difference == 0 হলে (আজকে আগেই লগইন করেছে) কিছুই হবে না
      }

      // ✅ যদি নতুন দিন হয়, তবে Firestore আপডেট করুন
      if (isNewDay) {
        await userRef.update({
          'lastLoginDate': FieldValue.serverTimestamp(),
          'loginStreak': currentStreak,
        });
        debugPrint('🔥 Login Streak Updated: $currentStreak days');
      }

      // ✅ ৭ দিন পূরণ হলে এবং আগে রিওয়ার্ড না নিয়ে থাকলে
      if (currentStreak == 7 && lastRewardClaimed != 7) {
        // রিওয়ার্ড দিন: ২৪ ঘণ্টার ফ্রি বুস্ট
        final boostUntil = DateTime.now().add(const Duration(hours: 24));

        await userRef.update({
          'boostedUntil': Timestamp.fromDate(boostUntil),
          'lastRewardClaimedStreak': 7, // রিওয়ার্ড ক্লেইম করা হলো
        });

        debugPrint('🎁 7-Day Streak Reward Claimed: Free Boost!');

        // UI তে দেখানোর জন্য রিটার্ন করুন
        return {
          'streak': currentStreak,
          'rewardGranted': true,
          'message':
              'অভিনন্দন! আপনি ৭ দিন টানা লগইন করেছেন। ২৪ ঘণ্টার ফ্রি বুস্ট পেয়েছেন!',
        };
      }

      // রিওয়ার্ড না পেলেও স্ট্রিক রিটার্ন করুন
      if (isNewDay) {
        return {
          'streak': currentStreak,
          'rewardGranted': false,
        };
      }

      return null; // আজকে আগেই লগইন করেছে, তাই কিছু রিটার্ন করার দরকার নেই
    } catch (e) {
      debugPrint('❌ Streak check error: $e');
      return null;
    }
  }
}
