import 'package:flutter/foundation.dart';

// ============================================================
// PROFILE COMPLETENESS SERVICE
// Calculates profile completion percentage + suggestions
// ============================================================

class CompletenessResult {
  final int percent;
  final List<String> completed;
  final List<CompletenessItem> pending;

  CompletenessResult({
    required this.percent,
    required this.completed,
    required this.pending,
  });

  bool get isComplete => percent >= 100;
  bool get isHigh => percent >= 80;
  bool get isMedium => percent >= 50;
}

class CompletenessItem {
  final String key;
  final String bnLabel;
  final String enLabel;
  final int weight;

  CompletenessItem({
    required this.key,
    required this.bnLabel,
    required this.enLabel,
    this.weight = 1,
  });
}

class ProfileCompletenessService {
  // ✅ Weighted items — important fields বেশি weight পায়
  static final List<CompletenessItem> items = [
    CompletenessItem(
      key: 'name',
      bnLabel: 'পূর্ণ নাম',
      enLabel: 'Full name',
      weight: 1,
    ),
    CompletenessItem(
      key: 'photoUrl',
      bnLabel: 'প্রোফাইল ছবি',
      enLabel: 'Profile photo',
      weight: 2,
    ),
    CompletenessItem(
      key: 'photoUrls',
      bnLabel: '৩টি অতিরিক্ত ছবি',
      enLabel: '3+ additional photos',
      weight: 2,
    ),
    CompletenessItem(
      key: 'age',
      bnLabel: 'বয়স',
      enLabel: 'Age',
      weight: 1,
    ),
    CompletenessItem(
      key: 'district',
      bnLabel: 'জেলা',
      enLabel: 'District',
      weight: 1,
    ),
    CompletenessItem(
      key: 'education',
      bnLabel: 'শিক্ষাগত যোগ্যতা',
      enLabel: 'Education',
      weight: 1,
    ),
    CompletenessItem(
      key: 'profession',
      bnLabel: 'পেশা',
      enLabel: 'Profession',
      weight: 1,
    ),
    CompletenessItem(
      key: 'maritalStatus',
      bnLabel: 'বৈবাহিক অবস্থা',
      enLabel: 'Marital status',
      weight: 1,
    ),
    CompletenessItem(
      key: 'aboutMe',
      bnLabel: 'নিজের সম্পর্কে',
      enLabel: 'About me',
      weight: 2,
    ),
    CompletenessItem(
      key: 'preferredAge',
      bnLabel: 'পছন্দের বয়স',
      enLabel: 'Preferred age',
      weight: 1,
    ),
    CompletenessItem(
      key: 'phone',
      bnLabel: 'মোবাইল নম্বর',
      enLabel: 'Phone number',
      weight: 1,
    ),
  ];

  static CompletenessResult calculate(Map<String, dynamic>? profile) {
    if (profile == null) {
      return CompletenessResult(
        percent: 0,
        completed: [],
        pending: items.map((i) => i).toList(),
      );
    }

    int totalWeight = items.fold(0, (sum, item) => sum + item.weight);
    int earnedWeight = 0;
    final List<String> completed = [];
    final List<CompletenessItem> pending = [];

    for (final item in items) {
      if (_isFieldFilled(profile, item.key)) {
        earnedWeight += item.weight;
        completed.add(item.key);
      } else {
        pending.add(item);
      }
    }

    final percent =
        totalWeight > 0 ? ((earnedWeight / totalWeight) * 100).round() : 0;

    return CompletenessResult(
      percent: percent,
      completed: completed,
      pending: pending,
    );
  }

  static bool _isFieldFilled(Map<String, dynamic> profile, String key) {
    final value = profile[key];

    if (value == null) return false;

    // photoUrls special — need 3+
    if (key == 'photoUrls') {
      if (value is List) return value.length >= 3;
      return false;
    }

    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is num) return value > 0;

    return true;
  }

  // Get color based on percent
  static int getColorValue(int percent) {
    if (percent >= 80) return 0xFF4CAF50; // Green
    if (percent >= 50) return 0xFFFFA726; // Orange
    return 0xFFE53935; // Red
  }

  // Bengali message based on percent
  static String getMessageBn(int percent) {
    if (percent >= 100) return '🎉 প্রোফাইল সম্পূর্ণ!';
    if (percent >= 80) return 'দারুণ! আরেকটু বাকি';
    if (percent >= 50) return 'ভালো চলছে, সম্পূর্ণ করুন';
    if (percent >= 25) return 'আরো তথ্য যোগ করা দরকার';
    return 'প্রোফাইল সম্পূর্ণ করুন';
  }

  static String getMessageEn(int percent) {
    if (percent >= 100) return '🎉 Profile complete!';
    if (percent >= 80) return 'Great! Almost there';
    if (percent >= 50) return 'Good going, complete it';
    if (percent >= 25) return 'More details needed';
    return 'Complete your profile';
  }
}
