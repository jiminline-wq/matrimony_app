import '../models/user_profile.dart';

class AiMatchService {
  // ✅ মেইন ফাংশন: ০ থেকে ১০০ এর মধ্যে স্কোর রিটার্ন করবে
  static double calculateScore(UserProfile me, UserProfile target) {
    double totalScore = 0.0;

    // ১. বয়সের ম্যাচ (সর্বোচ্চ ২৫ পয়েন্ট)
    totalScore += _calculateAgeScore(me.preferredAge, target.age);

    // ২. ধর্মের ম্যাচ (সর্বোচ্চ ২০ পয়েন্ট)
    totalScore += _calculateReligionScore(
        me.religion, me.preferredReligion, target.religion);

    // ৩. লোকেশনের ম্যাচ (সর্বোচ্চ ২০ পয়েন্ট)
    totalScore += _calculateLocationScore(me.district, target.district);

    // ৪. শিক্ষার ম্যাচ (সর্বোচ্চ ১৫ পয়েন্ট)
    totalScore +=
        _calculateEducationScore(me.preferredEducation, target.education);

    // ৫. পেশার ম্যাচ (সর্বোচ্চ ১০ পয়েন্ট)
    totalScore +=
        _calculateProfessionScore(me.preferredProfession, target.profession);

    // ৬. ট্রাস্ট ও প্রোফাইল কোয়ালিটি (সর্বোচ্চ ১০ পয়েন্ট)
    totalScore += _calculateTrustScore(target);

    // স্কোর ১০০ এর বেশি হলে ১০০ করে দিন
    return totalScore > 100 ? 100.0 : totalScore;
  }

  // ============================================================
  // ১. AGE SCORE (Max 25)
  // ============================================================
  static double _calculateAgeScore(String preferredAge, String targetAgeStr) {
    final targetAge = int.tryParse(targetAgeStr) ?? 0;
    if (targetAge == 0) return 10.0; // বয়স জানা না থাকলে ডিফল্ট

    // "25-30" বা "25 to 30" ফরম্যাট পার্স করা
    final RegExp rangeRegex = RegExp(r'(\d+)\s*(?:-|to)\s*(\d+)');
    final match = rangeRegex.firstMatch(preferredAge);

    if (match != null) {
      final minAge = int.parse(match.group(1)!);
      final maxAge = int.parse(match.group(2)!);

      if (targetAge >= minAge && targetAge <= maxAge) {
        return 25.0; // একদম পারফেক্ট রেঞ্জের মধ্যে
      } else if (targetAge >= minAge - 2 && targetAge <= maxAge + 2) {
        return 15.0; // রেঞ্জের একটু কাছাকাছি
      } else {
        return 5.0; // রেঞ্জের বাইরে
      }
    } else {
      // যদি শুধু একটি সংখ্যা থাকে (যেমন "25")
      final minAge = int.tryParse(preferredAge) ?? 0;
      if (minAge > 0) {
        final diff = (targetAge - minAge).abs();
        if (diff <= 3) return 25.0;
        if (diff <= 5) return 15.0;
        return 5.0;
      }
    }
    return 10.0; // ডিফল্ট
  }

  // ============================================================
  // ২. RELIGION SCORE (Max 20)
  // ============================================================
  static double _calculateReligionScore(
      String myReligion, String myPrefReligion, String targetReligion) {
    if (targetReligion == myReligion) return 20.0;
    if (targetReligion == myPrefReligion) return 15.0;
    return 0.0; // ভিন্ন ধর্ম
  }

  // ============================================================
  // ৩. LOCATION SCORE (Max 20)
  // ============================================================
  static double _calculateLocationScore(
      String myDistrict, String targetDistrict) {
    if (myDistrict == targetDistrict) return 20.0;
    // এখানে আপনি চাইলে বিভাগভিত্তিক ম্যাচিং যোগ করতে পারেন (যেমন: ঢাকা ও গাজীপুর একই বিভাগ)
    // আপাতত ভিন্ন জেলার জন্য ৫ পয়েন্ট
    return 5.0;
  }

  // ============================================================
  // ৪. EDUCATION SCORE (Max 15)
  // ============================================================
  static double _calculateEducationScore(
      String myPrefEducation, String targetEducation) {
    if (targetEducation.isEmpty || myPrefEducation.isEmpty) return 5.0;

    final myPrefLower = myPrefEducation.toLowerCase();
    final targetLower = targetEducation.toLowerCase();

    // কীওয়ার্ড ম্যাচিং (যেমন: BSc, Bachelor, Graduate)
    if (targetLower.contains(myPrefLower) ||
        myPrefLower.contains(targetLower)) {
      return 15.0;
    }

    // সাধারণ কীওয়ার্ড চেক
    final keywords = [
      'bsc',
      'b.a',
      'ba',
      'bachelor',
      'masters',
      'msc',
      'graduate',
      'hsc',
      'ssc'
    ];
    for (var keyword in keywords) {
      if (myPrefLower.contains(keyword) && targetLower.contains(keyword)) {
        return 12.0;
      }
    }
    return 5.0;
  }

  // ============================================================
  // ৫. PROFESSION SCORE (Max 10)
  // ============================================================
  static double _calculateProfessionScore(
      String myPrefProfession, String targetProfession) {
    if (targetProfession.isEmpty || myPrefProfession.isEmpty) return 5.0;

    final myPrefLower = myPrefProfession.toLowerCase();
    final targetLower = targetProfession.toLowerCase();

    // কীওয়ার্ড ম্যাচিং (যেমন: Engineer, Doctor, Teacher, Govt)
    if (targetLower.contains(myPrefLower) ||
        myPrefLower.contains(targetLower)) {
      return 10.0;
    }

    final categories = [
      'engineer',
      'doctor',
      'teacher',
      'govt',
      'business',
      'it',
      'banker',
      'student'
    ];
    for (var cat in categories) {
      if (myPrefLower.contains(cat) && targetLower.contains(cat)) {
        return 8.0;
      }
    }
    return 3.0;
  }

  // ============================================================
  // ৬. TRUST & PROFILE QUALITY SCORE (Max 10)
  // ============================================================
  static double _calculateTrustScore(UserProfile target) {
    double score = 0.0;

    // ভেরিফাইড হলে +৫
    if (target.isVerified) {
      score += 5.0;
    }

    // ৩টির বেশি ছবি থাকলে +৩
    if (target.photoUrls.length >= 3) {
      score += 3.0;
    } else if (target.photoUrls.isNotEmpty) {
      score += 1.0;
    }

    // 'About Me' পুরো ৫০ অক্ষরের বেশি হলে +২
    if (target.aboutMe.length > 50) {
      score += 2.0;
    }

    return score;
  }
}
