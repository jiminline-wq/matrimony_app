import 'package:flutter/material.dart';


// ============================================================
// FILTER OPTIONS MODEL
// ============================================================

class FilterOptions {
  final RangeValues ageRange;
  final String? district;
  final String? religion;
  final String? education;
  final String? profession;
  final String? maritalStatus;
  final String? gender; // ✅ NEW

  const FilterOptions({
    this.ageRange = const RangeValues(18, 60),
    this.district,
    this.religion,
    this.education,
    this.profession,
    this.maritalStatus,
    this.gender, // ✅ NEW
  });

  // কোনো filter active আছে কিনা
  bool get isActive {
    return ageRange.start > 18 ||
        ageRange.end < 60 ||
        district != null ||
        religion != null ||
        education != null ||
        profession != null ||
        maritalStatus != null ||
        gender != null; // ✅ NEW
  }

  // কতগুলো filter active
  int get activeCount {
    int count = 0;
    if (ageRange.start > 18 || ageRange.end < 60) count++;
    if (district != null) count++;
    if (religion != null) count++;
    if (education != null) count++;
    if (profession != null) count++;
    if (maritalStatus != null) count++;
    if (gender != null) count++; // ✅ NEW
    return count;
  }

  FilterOptions copyWith({
    RangeValues? ageRange,
    String? district,
    String? religion,
    String? education,
    String? profession,
    String? maritalStatus,
    String? gender, // ✅ NEW
    bool clearDistrict = false,
    bool clearReligion = false,
    bool clearEducation = false,
    bool clearProfession = false,
    bool clearMaritalStatus = false,
    bool clearGender = false, // ✅ NEW
  }) {
    return FilterOptions(
      ageRange: ageRange ?? this.ageRange,
      district: clearDistrict ? null : (district ?? this.district),
      religion: clearReligion ? null : (religion ?? this.religion),
      education: clearEducation ? null : (education ?? this.education),
      profession: clearProfession ? null : (profession ?? this.profession),
      maritalStatus:
          clearMaritalStatus ? null : (maritalStatus ?? this.maritalStatus),
      gender: clearGender ? null : (gender ?? this.gender), // ✅ NEW
    );
  }

  // Reset — সব null
  static const empty = FilterOptions();
}