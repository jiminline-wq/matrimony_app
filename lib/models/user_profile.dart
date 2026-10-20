import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// USER PROFILE MODEL
// ============================================================

class UserProfile {
  final String uid;
  final String name;
  final String gender;
  final String religion;
  final String email;
  final String phone;
  final String age;
  final String district;
  final String maritalStatus;
  final String education;
  final String profession;
  final String aboutMe;
  final String preferredAge;
  final String preferredReligion;
  final String preferredEducation;
  final String preferredProfession;
  final String photoUrl;
  final List<String> photoUrls;
  final String height;
  final String skinTone;
  final Timestamp? boostedUntil;
  final bool isVerified;

  UserProfile({
    required this.uid,
    required this.name,
    required this.gender,
    required this.religion,
    required this.email,
    required this.phone,
    required this.age,
    required this.district,
    required this.maritalStatus,
    required this.education,
    required this.profession,
    required this.aboutMe,
    required this.preferredAge,
    required this.preferredReligion,
    required this.preferredEducation,
    required this.preferredProfession,
    required this.photoUrl,
    required this.photoUrls,
    required this.height,
    required this.skinTone,
    this.boostedUntil,
    this.isVerified = false,
  });

  bool get isBoosted {
    if (boostedUntil == null) return false;
    return boostedUntil!.toDate().isAfter(DateTime.now());
  }

  // ============================================================
  // TO MAP
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'gender': gender,
      'religion': religion,
      'email': email,
      'phone': phone,
      'age': age,
      'district': district,
      'maritalStatus': maritalStatus,
      'education': education,
      'profession': profession,
      'aboutMe': aboutMe,
      'preferredAge': preferredAge,
      'preferredReligion': preferredReligion,
      'preferredEducation': preferredEducation,
      'preferredProfession': preferredProfession,
      'photoUrl': photoUrl,
      'photoUrls': photoUrls,
      'height': height,
      'skinTone': skinTone,
      if (boostedUntil != null) 'boostedUntil': boostedUntil,
      'isVerified': isVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ============================================================
  // FROM MAP — with docId fallback (PERMANENT FIX)
  // ============================================================
  factory UserProfile.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Photo URLs parse
    List<String> parsedPhotoUrls = [];
    if (map['photoUrls'] is List) {
      parsedPhotoUrls = List<String>.from(
        (map['photoUrls'] as List).map((e) => e.toString()),
      );
    }
    if (parsedPhotoUrls.isEmpty) {
      final mainPhoto = (map['photoUrl'] ?? '').toString();
      if (mainPhoto.isNotEmpty) {
        parsedPhotoUrls = [mainPhoto];
      }
    }

// ✅ UID resolution: map['uid'] → docId → ''
    String resolvedUid = (map['uid'] ?? '').toString().trim();
    if (resolvedUid.isEmpty) {
      resolvedUid = (docId ?? '').toString().trim();
    }

    return UserProfile(
      uid: resolvedUid,
      name: (map['name'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      religion: (map['religion'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      age: (map['age'] ?? '').toString(),
      district: (map['district'] ?? '').toString(),
      maritalStatus: (map['maritalStatus'] ?? '').toString(),
      education: (map['education'] ?? '').toString(),
      profession: (map['profession'] ?? '').toString(),
      aboutMe: (map['aboutMe'] ?? '').toString(),
      preferredAge: (map['preferredAge'] ?? '').toString(),
      preferredReligion: (map['preferredReligion'] ?? '').toString(),
      preferredEducation: (map['preferredEducation'] ?? '').toString(),
      preferredProfession: (map['preferredProfession'] ?? '').toString(),
      photoUrl: (map['photoUrl'] ?? '').toString(),
      photoUrls: parsedPhotoUrls,
      height: (map['height'] ?? '').toString(),
      skinTone: (map['skinTone'] ?? '').toString(),
      boostedUntil: map['boostedUntil'] as Timestamp?,
      isVerified: map['isVerified'] == true,
    );
  }

  // ✅ Convenience factory — from Firestore DocumentSnapshot
  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile.fromMap(data, docId: doc.id);
  }
}

// ============================================================
// EDUCATION MODEL
// ============================================================

class EducationEntry {
  String degree;
  String board;
  String subject;
  String institution;
  String year;
  bool currentlyStudying;

  EducationEntry({
    this.degree = '',
    this.board = '',
    this.subject = '',
    this.institution = '',
    this.year = '',
    this.currentlyStudying = false,
  });
}

// ============================================================
// PROFESSION MODEL
// ============================================================

class ProfessionEntry {
  String type;
  String designation;
  String organization;
  String department;
  String location;
  String startYear;
  String endYear;
  String description;

  String businessName;
  String businessType;
  String businessCategory;

  bool isCurrent;

  ProfessionEntry({
    this.type = '',
    this.designation = '',
    this.organization = '',
    this.department = '',
    this.location = '',
    this.startYear = '',
    this.endYear = '',
    this.description = '',
    this.businessName = '',
    this.businessType = '',
    this.businessCategory = '',
    this.isCurrent = true,
  });
}
