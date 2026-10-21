import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../models/filter_options.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ============================================================
// FILTER SCREEN
// ============================================================

class FilterScreen extends StatefulWidget {
  final bool isBangla;
  final FilterOptions initialFilter;

  const FilterScreen({
    super.key,
    required this.isBangla,
    required this.initialFilter,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late RangeValues _ageRange;
  String? _district;
  String? _religion;
  String? _education;
  String? _profession;
  String? _maritalStatus;
  String? _gender; // ✅ NEW

  // ============================================================
  // DATA OPTIONS
  // ============================================================

  final List<String> districts = [
    'Bagerhat',
    'Bandarban',
    'Barguna',
    'Barishal',
    'Bhola',
    'Bogura',
    'Brahmanbaria',
    'Chandpur',
    'Chattogram',
    'Chuadanga',
    "Cox's Bazar",
    'Cumilla',
    'Dhaka',
    'Dinajpur',
    'Faridpur',
    'Feni',
    'Gaibandha',
    'Gazipur',
    'Gopalganj',
    'Habiganj',
    'Jamalpur',
    'Jashore',
    'Jhalokathi',
    'Jhenaidah',
    'Joypurhat',
    'Khagrachhari',
    'Khulna',
    'Kishoreganj',
    'Kurigram',
    'Kushtia',
    'Lakshmipur',
    'Lalmonirhat',
    'Madaripur',
    'Magura',
    'Manikganj',
    'Meherpur',
    'Moulvibazar',
    'Munshiganj',
    'Mymensingh',
    'Naogaon',
    'Narail',
    'Narayanganj',
    'Narsingdi',
    'Natore',
    'Netrokona',
    'Nilphamari',
    'Noakhali',
    'Pabna',
    'Panchagarh',
    'Patuakhali',
    'Pirojpur',
    'Rajbari',
    'Rajshahi',
    'Rangamati',
    'Rangpur',
    'Satkhira',
    'Shariatpur',
    'Sherpur',
    'Sirajganj',
    'Sunamganj',
    'Sylhet',
    'Tangail',
    'Thakurgaon',
  ];

  final List<String> religions = [
    'Islam',
    'Hinduism',
    'Christianity',
    'Buddhism',
    'Other',
  ];

  final List<String> genders = [
    'Male',
    'Female',
  ];

  final List<String> educations = [
    'SSC',
    'HSC',
    'Diploma',
    'Bachelor',
    'BSc',
    'BSc in Engineering',
    'BA',
    'BBA',
    'BSS',
    'BCom',
    'LLB',
    'MBBS',
    'BDS',
    'BPharm',
    'BSc Nursing',
    'Master',
    'MSc',
    'MA',
    'MBA',
    'MSS',
    'LLM',
    'MPharm',
    'MPH',
    'MPhil',
    'PhD',
  ];

  final List<String> professions = [
    'Government Job',
    'Private Job',
    'Teacher',
    'Engineer',
    'Doctor',
    'Banker',
    'Lawyer',
    'Freelancer',
    'Business',
    'Student',
    'House Maker',
    'Other',
  ];

  final List<String> maritalStatuses = [
    'Never Married',
    'Divorced',
    'Widowed',
    'Separated',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _ageRange = widget.initialFilter.ageRange;
    _district = widget.initialFilter.district;
    _religion = widget.initialFilter.religion;
    _education = widget.initialFilter.education;
    _profession = widget.initialFilter.profession;
    _maritalStatus = widget.initialFilter.maritalStatus;
    _gender = widget.initialFilter.gender;
  }

  // ============================================================
  // APPLY
  // ============================================================

  void _applyFilters() {
    final filter = FilterOptions(
      ageRange: _ageRange,
      district: _district,
      religion: _religion,
      education: _education,
      profession: _profession,
      maritalStatus: _maritalStatus,
      gender: _gender,
    );

    Navigator.pop(context, filter);
  }

  void _clearAll() {
    setState(() {
      _ageRange = const RangeValues(18, 60);
      _district = null;
      _religion = null;
      _education = null;
      _profession = null;
      _maritalStatus = null;
      _gender = null;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          bn ? 'ফিল্টার' : 'Filter',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
        actions: [
          TextButton(
            onPressed: _clearAll,
            child: Text(
              bn ? 'রিসেট' : 'Reset',
              style: const TextStyle(
                color: primaryMaroon,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          // ✅ ফিল্টার লিস্ট
          Widget filterList = ListView(
            // ✅ নিচে padding বাড়ানো হলো যাতে অ্যাড ও বাটনের জন্য জায়গা থাকে
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 150),
            children: [
              _buildSectionTitle(bn ? 'বয়স' : 'Age Range', Icons.cake_outlined),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_ageRange.start.round()}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryMaroon)),
                        Text('${_ageRange.end.round()}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryMaroon)),
                      ],
                    ),
                    RangeSlider(
                      values: _ageRange,
                      min: 18,
                      max: 60,
                      divisions: 42,
                      activeColor: primaryMaroon,
                      inactiveColor: lightMaroon,
                      labels: RangeLabels('${_ageRange.start.round()}',
                          '${_ageRange.end.round()}'),
                      onChanged: (values) => setState(() => _ageRange = values),
                    ),
                    Text(
                      bn
                          ? '${_ageRange.start.round()} - ${_ageRange.end.round()} বছর'
                          : '${_ageRange.start.round()} - ${_ageRange.end.round()} years',
                      style:
                          const TextStyle(fontSize: 13, color: secondaryText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(bn ? 'লিঙ্গ' : 'Gender', Icons.wc_outlined),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _gender,
                hint: bn ? 'যেকোনো লিঙ্গ' : 'Any gender',
                items: genders,
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  bn ? 'জেলা' : 'District', Icons.location_on_outlined),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _district,
                hint: bn ? 'সব জেলা' : 'Any district',
                items: districts,
                onChanged: (value) => setState(() => _district = value),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  bn ? 'ধর্ম' : 'Religion', Icons.auto_awesome_outlined),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _religion,
                hint: bn ? 'সব ধর্ম' : 'Any religion',
                items: religions,
                onChanged: (value) => setState(() => _religion = value),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  bn ? 'শিক্ষা' : 'Education', Icons.school_outlined),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _education,
                hint: bn ? 'যেকোনো শিক্ষা' : 'Any education',
                items: educations,
                onChanged: (value) => setState(() => _education = value),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(
                  bn ? 'পেশা' : 'Profession', Icons.work_outline),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _profession,
                hint: bn ? 'যেকোনো পেশা' : 'Any profession',
                items: professions,
                onChanged: (value) => setState(() => _profession = value),
              ),
              const SizedBox(height: 20),
              _buildSectionTitle(bn ? 'বৈবাহিক অবস্থা' : 'Marital Status',
                  Icons.favorite_border),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _maritalStatus,
                hint: bn ? 'যেকোনো' : 'Any',
                items: maritalStatuses,
                onChanged: (value) => setState(() => _maritalStatus = value),
              ),
            ],
          );

          // ✅ ওয়েবে সুন্দর কার্ডের ভেতরে দেখানোর জন্য
          if (isDesktop) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: warmWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: filterList,
                  ),
                ),
              ),
            );
          }

          // মোবাইলে আগের মতোই ফুল স্ক্রিন
          return filterList;
        },
      ),
      // ✅ বাটন এবং অ্যাড একসাথে নিচে ফিক্সড করা হলো
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: primaryMaroon.withValues(alpha: 0.10),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        bn ? 'ফিল্টার প্রয়োগ করুন' : 'Apply Filters',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ✅ AdMob শুধু মোবাইলে
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                const BannerAdWidget(
                  placementId: AdConfig.placementFilterApply,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: lightMaroon,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: primaryMaroon),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: mainText,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: secondaryText.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: primaryMaroon),
          items: [
            ...items.map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: mainText,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
