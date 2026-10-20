import 'package:cloud_firestore/cloud_firestore.dart';
import 'bd_districts.dart';

// ============================================================
// DISTRICT MIGRATION
// একবার চালান, তারপর এই ফাইল মুছে ফেলুন
// পুরনো user দের district বাংলা/inconsistent থাকলে English এ fix করবে
// ============================================================

class DistrictMigration {
  /// বাংলা → English ম্যাপিং
  static const Map<String, String> _banglaToEnglish = {
    'ঢাকা': 'Dhaka',
    'চট্টগ্রাম': 'Chattogram',
    'চিটাগাং': 'Chattogram',
    'খুলনা': 'Khulna',
    'রাজশাহী': 'Rajshahi',
    'সিলেট': 'Sylhet',
    'বরিশাল': 'Barishal',
    'রংপুর': 'Rangpur',
    'ময়মনসিংহ': 'Mymensingh',
    'কুমিল্লা': 'Cumilla',
    'কমিল্লা': 'Cumilla',
    'নারায়ণগঞ্জ': 'Narayanganj',
    'গাজীপুর': 'Gazipur',
    'বগুড়া': 'Bogura',
    'যশোর': 'Jashore',
    'কক্সবাজার': "Cox's Bazar",
    'কক্স বাজার': "Cox's Bazar",
    'ফেনী': 'Feni',
    'নোয়াখালী': 'Noakhali',
    'লক্ষ্মীপুর': 'Lakshmipur',
    'চাঁদপুর': 'Chandpur',
    'ব্রাহ্মণবাড়িয়া': 'Brahmanbaria',
    'রাঙ্গামাটি': 'Rangamati',
    'বান্দরবান': 'Bandarban',
    'খাগড়াছড়ি': 'Khagrachhari',
    'নরসিংদী': 'Narsingdi',
    'মুন্সিগঞ্জ': 'Munshiganj',
    'মানিকগঞ্জ': 'Manikganj',
    'টাঙ্গাইল': 'Tangail',
    'কিশোরগঞ্জ': 'Kishoreganj',
    'নেত্রকোনা': 'Netrokona',
    'জামালপুর': 'Jamalpur',
    'শেরপুর': 'Sherpur',
    'গোপালগঞ্জ': 'Gopalganj',
    'মাদারীপুর': 'Madaripur',
    'শরীয়তপুর': 'Shariatpur',
    'রাজবাড়ী': 'Rajbari',
    'ফরিদপুর': 'Faridpur',
    'পাবনা': 'Pabna',
    'সিরাজগঞ্জ': 'Sirajganj',
    'নাটোর': 'Natore',
    'নওগাঁ': 'Naogaon',
    'চাঁপাইনবাবগঞ্জ': 'Chapainawabganj',
    'জয়পুরহাট': 'Joypurhat',
    'কুষ্টিয়া': 'Kushtia',
    'চুয়াডাঙ্গা': 'Chuadanga',
    'মেহেরপুর': 'Meherpur',
    'ঝিনাইদহ': 'Jhenaidah',
    'মাগুরা': 'Magura',
    'নড়াইল': 'Narail',
    'সাতক্ষীরা': 'Satkhira',
    'বাগেরহাট': 'Bagerhat',
    'পিরোজপুর': 'Pirojpur',
    'ঝালকাঠি': 'Jhalokathi',
    'পটুয়াখালী': 'Patuakhali',
    'ভোলা': 'Bhola',
    'বরগুনা': 'Barguna',
    'হবিগঞ্জ': 'Habiganj',
    'মৌলভীবাজার': 'Moulvibazar',
    'সুনামগঞ্জ': 'Sunamganj',
    'দিনাজপুর': 'Dinajpur',
    'গাইবান্ধা': 'Gaibandha',
    'কুড়িগ্রাম': 'Kurigram',
    'লালমনিরহাট': 'Lalmonirhat',
    'নীলফামারী': 'Nilphamari',
    'পঞ্চগড়': 'Panchagarh',
    'ঠাকুরগাঁও': 'Thakurgaon',
  };

  /// বাংলা/case/all-apace variation → English name (match করা)
  static String? _normalize(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;

    // 1. Exact match
    if (bdDistricts.contains(t)) return t;

    // 2. Bangla map
    if (_banglaToEnglish.containsKey(t)) return _banglaToEnglish[t];

    // 3. Case-insensitive
    for (final d in bdDistricts) {
      if (d.toLowerCase() == t.toLowerCase()) return d;
    }

    // 4. Remove extra spaces, try again
    final cleaned = t.replaceAll(RegExp(r'\s+'), ' ');
    for (final d in bdDistricts) {
      if (d.toLowerCase() == cleaned.toLowerCase()) return d;
    }

    return null;
  }

  /// সব user scan করে district fix করে
  /// Return: { total, fixed, skipped, errors }
  static Future<Map<String, int>> run() async {
    int total = 0;
    int fixed = 0;
    int skipped = 0;
    int errors = 0;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(1000)
          .get();

      total = snap.docs.length;

      final batches = <WriteBatch>[];
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int ops = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final old = (data['district'] ?? '').toString();
        final normalized = _normalize(old);

        if (normalized == null) {
          // মিলল না — skip (user নিজে পরে edit করবে)
          skipped++;
          continue;
        }

        if (normalized == old) {
          // Already ঠিক আছে
          skipped++;
          continue;
        }

        batch.update(doc.reference, {
          'district': normalized,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        ops++;
        fixed++;

        // Firestore batch max 500 — ভরে গেলে commit করে নতুন batch
        if (ops >= 450) {
          batches.add(batch);
          batch = FirebaseFirestore.instance.batch();
          ops = 0;
        }
      }

      if (ops > 0) batches.add(batch);

      for (final b in batches) {
        try {
          await b.commit();
        } catch (_) {
          errors++;
        }
      }

      return {
        'total': total,
        'fixed': fixed,
        'skipped': skipped,
        'errors': errors,
      };
    } catch (_) {
      return {
        'total': total,
        'fixed': fixed,
        'skipped': skipped,
        'errors': errors + 1,
      };
    }
  }
}