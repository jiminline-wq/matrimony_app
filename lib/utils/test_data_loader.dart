import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// ⚠️ TEST DATA LOADER — শুধু Development-এর জন্য ⚠️
// Production-এ এই file delete করতে হবে!
// ============================================================

class TestDataLoader {
  static Future<int> loadTestUsers() async {
    final firestore = FirebaseFirestore.instance;
    final List<Map<String, dynamic>> testUsers = [
      // ============================================================
      // FEMALE USERS (1-10)
      // ============================================================
      {
        'uid': 'test_female_1',
        'name': 'Fatema Akter',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'fatema.test@jibonsathi.com',
        'phone': '01711111111',
        'age': '24',
        'district': 'Dhaka',
        'maritalStatus': 'Never Married',
        'education': 'BSc in CSE, Dhaka University',
        'profession': 'Software Engineer',
        'aboutMe':
            'আমি একজন সফটওয়্যার ইঞ্জিনিয়ার। পড়তে, ঘুরতে, আর নতুন জিনিস শিখতে ভালোবাসি।',
        'preferredAge': '26 - 32',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Government Job',
        'photoUrl': 'https://i.pravatar.cc/400?img=1',
        'height': "5'4\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_2',
        'name': 'Nusrat Jahan',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'nusrat.test@jibonsathi.com',
        'phone': '01722222222',
        'age': '27',
        'district': 'Chattogram',
        'maritalStatus': 'Never Married',
        'education': 'MBBS, Chittagong Medical College',
        'profession': 'Doctor',
        'aboutMe': 'ডাক্তার। মানুষের সেবা করতে ভালোবাসি।',
        'preferredAge': '28 - 35',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Master',
        'preferredProfession': 'Doctor',
        'photoUrl': 'https://i.pravatar.cc/400?img=5',
        'height': "5'3\"",
        'skinTone': 'Wheatish (উজ্জ্বল শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_3',
        'name': 'Tasnim Rahman',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'tasnim.test@jibonsathi.com',
        'phone': '01733333333',
        'age': '26',
        'district': 'Sylhet',
        'maritalStatus': 'Never Married',
        'education': 'MBA, IBA',
        'profession': 'Banker',
        'aboutMe': 'ব্যাংকার। ঘুরতে আর খাবার রান্না করতে ভালোবাসি।',
        'preferredAge': '27 - 35',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Master',
        'preferredProfession': 'Banker',
        'photoUrl': 'https://i.pravatar.cc/400?img=9',
        'height': "5'5\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_4',
        'name': 'Sadia Islam',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'sadia.test@jibonsathi.com',
        'phone': '01744444444',
        'age': '23',
        'district': 'Rajshahi',
        'maritalStatus': 'Never Married',
        'education': 'HSC, Rajshahi College',
        'profession': 'Student',
        'aboutMe': 'ছাত্রী। পড়াশোনা আর গান শুনতে ভালোবাসি।',
        'preferredAge': '24 - 30',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Engineer',
        'photoUrl': 'https://i.pravatar.cc/400?img=10',
        'height': "5'2\"",
        'skinTone': 'Wheatish (উজ্জ্বল শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_5',
        'name': 'Rumana Haque',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'rumana.test@jibonsathi.com',
        'phone': '01755555555',
        'age': '30',
        'district': 'Khulna',
        'maritalStatus': 'Divorced',
        'education': 'MA in English, Khulna University',
        'profession': 'Teacher',
        'aboutMe': 'ইংরেজি শিক্ষক। বই পড়া আর ভ্রমণ করতে ভালোবাসি।',
        'preferredAge': '30 - 40',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Master',
        'preferredProfession': 'Teacher',
        'photoUrl': 'https://i.pravatar.cc/400?img=16',
        'height': "5'4\"",
        'skinTone': 'Medium (শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_6',
        'name': 'Farhana Yasmin',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'farhana.test@jibonsathi.com',
        'phone': '01766666666',
        'age': '28',
        'district': 'Dhaka',
        'maritalStatus': 'Never Married',
        'education': 'LLB, Dhaka University',
        'profession': 'Lawyer',
        'aboutMe': 'আইনজীবী। সত্যের পক্ষে লড়াই করতে ভালোবাসি।',
        'preferredAge': '28 - 35',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Lawyer',
        'photoUrl': 'https://i.pravatar.cc/400?img=20',
        'height': "5'5\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_7',
        'name': 'Jannatul Ferdous',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'jannat.test@jibonsathi.com',
        'phone': '01777777777',
        'age': '25',
        'district': 'Cumilla',
        'maritalStatus': 'Never Married',
        'education': 'BBA, Comilla University',
        'profession': 'Freelancer',
        'aboutMe': 'ফ্রিল্যান্সার। লেখালেখি আর photography ভালোবাসি।',
        'preferredAge': '26 - 32',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Engineer',
        'photoUrl': 'https://i.pravatar.cc/400?img=25',
        'height': "5'3\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_8',
        'name': 'Arifa Sultana',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'arifa.test@jibonsathi.com',
        'phone': '01788888888',
        'age': '32',
        'district': 'Mymensingh',
        'maritalStatus': 'Never Married',
        'education': 'MSc in Botany, BAU',
        'profession': 'Researcher',
        'aboutMe': 'গবেষক। গাছপালা আর প্রকৃতি ভালোবাসি।',
        'preferredAge': '32 - 40',
        'preferredReligion': 'Islam',
        'preferredEducation': 'PhD',
        'preferredProfession': 'Teacher',
        'photoUrl': 'https://i.pravatar.cc/400?img=32',
        'height': "5'2\"",
        'skinTone': 'Wheatish (উজ্জ্বল শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_9',
        'name': 'Saima Chowdhury',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'saima.test@jibonsathi.com',
        'phone': '01799999999',
        'age': '29',
        'district': 'Barishal',
        'maritalStatus': 'Never Married',
        'education': 'BDS, Dhaka Dental College',
        'profession': 'Dentist',
        'aboutMe': 'ডেন্টিস্ট। হাসিমুখ মানুষ দেখতে ভালোবাসি।',
        'preferredAge': '30 - 37',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Doctor',
        'photoUrl': 'https://i.pravatar.cc/400?img=44',
        'height': "5'4\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_female_10',
        'name': 'Mahiya Rahman',
        'gender': 'Female',
        'religion': 'Islam',
        'email': 'mahiya.test@jibonsathi.com',
        'phone': '01710101010',
        'age': '22',
        'district': 'Rangpur',
        'maritalStatus': 'Never Married',
        'education': 'HSC, Rangpur Govt College',
        'profession': 'Student',
        'aboutMe': 'ছাত্রী। নতুন কিছু শিখতে ভালোবাসি।',
        'preferredAge': '23 - 28',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Engineer',
        'photoUrl': 'https://i.pravatar.cc/400?img=47',
        'height': "5'1\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },

      // ============================================================
      // MALE USERS (11-15)
      // ============================================================
      {
        'uid': 'test_male_1',
        'name': 'Rafi Ahmed',
        'gender': 'Male',
        'religion': 'Islam',
        'email': 'rafi.test@jibonsathi.com',
        'phone': '01711111112',
        'age': '30',
        'district': 'Dhaka',
        'maritalStatus': 'Never Married',
        'education': 'BSc in CSE, BUET',
        'profession': 'Software Engineer',
        'aboutMe': 'Software Engineer। নতুন প্রযুক্তি ভালোবাসি।',
        'preferredAge': '22 - 28',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Teacher',
        'photoUrl': 'https://i.pravatar.cc/400?img=12',
        'height': "5'10\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_male_2',
        'name': 'Tanvir Hasan',
        'gender': 'Male',
        'religion': 'Islam',
        'email': 'tanvir.test@jibonsathi.com',
        'phone': '01722222223',
        'age': '28',
        'district': 'Chattogram',
        'maritalStatus': 'Never Married',
        'education': 'MBA, IBA',
        'profession': 'Banker',
        'aboutMe': 'ব্যাংকার। ঘুরতে আর football খেলতে ভালোবাসি।',
        'preferredAge': '22 - 27',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Doctor',
        'photoUrl': 'https://i.pravatar.cc/400?img=33',
        'height': "5'11\"",
        'skinTone': 'Wheatish (উজ্জ্বল শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_male_3',
        'name': 'Shakib Khan',
        'gender': 'Male',
        'religion': 'Islam',
        'email': 'shakib.test@jibonsathi.com',
        'phone': '01733333334',
        'age': '33',
        'district': 'Sylhet',
        'maritalStatus': 'Never Married',
        'education': 'MBBS, Sylhet MAG Osmani Medical College',
        'profession': 'Doctor',
        'aboutMe': 'ডাক্তার। মানুষের সেবা করাই আমার লক্ষ্য।',
        'preferredAge': '24 - 30',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Doctor',
        'photoUrl': 'https://i.pravatar.cc/400?img=52',
        'height': "5'9\"",
        'skinTone': 'Wheatish (উজ্জ্বল শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_male_4',
        'name': 'Imran Hossain',
        'gender': 'Male',
        'religion': 'Islam',
        'email': 'imran.test@jibonsathi.com',
        'phone': '01744444445',
        'age': '26',
        'district': 'Rajshahi',
        'maritalStatus': 'Never Married',
        'education': 'BSc in EEE, RUET',
        'profession': 'Engineer',
        'aboutMe': 'ইঞ্জিনিয়ার। ঘুরতে আর গান শুনতে ভালোবাসি।',
        'preferredAge': '21 - 26',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Bachelor',
        'preferredProfession': 'Teacher',
        'photoUrl': 'https://i.pravatar.cc/400?img=57',
        'height': "5'10\"",
        'skinTone': 'Medium (শ্যামলা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'test_male_5',
        'name': 'Mehedi Hasan',
        'gender': 'Male',
        'religion': 'Islam',
        'email': 'mehedi.test@jibonsathi.com',
        'phone': '01755555556',
        'age': '35',
        'district': 'Khulna',
        'maritalStatus': 'Divorced',
        'education': 'LLM, University of Dhaka',
        'profession': 'Lawyer',
        'aboutMe': 'আইনজীবী। সত্যের পক্ষে লড়াই করি।',
        'preferredAge': '28 - 35',
        'preferredReligion': 'Islam',
        'preferredEducation': 'Master',
        'preferredProfession': 'Lawyer',
        'photoUrl': 'https://i.pravatar.cc/400?img=59',
        'height': "5'11\"",
        'skinTone': 'Fair (ফর্সা)',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    int successCount = 0;

    for (final user in testUsers) {
      try {
        final uid = user['uid'] as String;
        await firestore.collection('users').doc(uid).set(user);
        successCount++;
        debugPrint('✅ Created: ${user['name']}');
      } catch (e) {
        debugPrint('❌ Failed: ${user['name']} - $e');
      }
    }

    return successCount;
  }

  // ============================================================
  // Test User Delete
  // ============================================================

  static Future<int> deleteTestUsers() async {
    final firestore = FirebaseFirestore.instance;
    int deleteCount = 0;

    try {
      final snapshot = await firestore.collection('users').get();

      for (final doc in snapshot.docs) {
        final uid = doc.data()['uid'] as String? ?? '';
        if (uid.startsWith('test_')) {
          await doc.reference.delete();
          deleteCount++;
        }
      }
    } catch (e) {
      debugPrint('Delete error: $e');
    }

    return deleteCount;
  }
}