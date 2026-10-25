import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import 'profile_details_screen.dart';

// ============================================================
// PROFILE SETUP SCREEN
// ============================================================

class ProfileSetupScreen extends StatefulWidget {
  final bool isBangla;
  final String name;
  final String gender;
  final String religion;
  final String email;
  final String phone;

  const ProfileSetupScreen({
    super.key,
    required this.isBangla,
    required this.name,
    required this.gender,
    required this.religion,
    required this.email,
    required this.phone,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final formKey = GlobalKey<FormState>();

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  final ageController = TextEditingController();
  String? district;
  String? maritalStatus;
  String? height;
  String? skinTone;

  // ============================================================
  // EDUCATION
  // ============================================================

  List<EducationEntry> educationEntries = [
    EducationEntry(),
  ];

  // ============================================================
  // PROFESSION
  // ============================================================

  String? currentStatus;

  List<ProfessionEntry> currentJobs = [];
  List<ProfessionEntry> previousJobs = [];

  // ============================================================
  // DISTRICTS
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

  // ============================================================
  // MARITAL STATUS
  // ============================================================

  final List<String> maritalStatuses = [
    'Never Married',
    'Divorced',
    'Widowed',
    'Separated',
  ];

  // ============================================================
  // EDUCATION DEGREES
  // ============================================================

  final List<String> educationDegrees = [
    'SSC',
    'Dakhil',
    'O-Level',
    'SSC Vocational',
    'Secondary Equivalent',
    'Other Secondary',
    'HSC',
    'Alim',
    'A-Level',
    'HSC Vocational',
    'Higher Secondary Equivalent',
    'Other Higher Secondary',
    'Diploma in Engineering',
    'Diploma in Medical',
    'Diploma in Nursing',
    'Diploma in Agriculture',
    'Diploma in Pharmacy',
    'Diploma in Textile',
    'Diploma in Architecture',
    'Other Diploma',
    'BSc',
    'BSc in Engineering',
    'BA',
    'BBA',
    'BSS',
    'BCom',
    'BEd',
    'BFA',
    'LLB',
    'MBBS',
    'BDS',
    'BPharm',
    'BSc Nursing',
    'BSc in Agriculture',
    'BSc in Textile',
    'BArch',
    'Bachelor Equivalent',
    'Other Bachelor',
    'MSc',
    'MA',
    'MBA',
    'MSS',
    'MCom',
    'MEd',
    'LLM',
    'MPharm',
    'MPH',
    'MSc Nursing',
    'MSc in Engineering',
    'MSc in Agriculture',
    'MSc in Computer Science',
    'Master Equivalent',
    'Other Master',
    'MPhil',
    'PhD',
    'Post-Doctoral',
    'Other Higher Degree',
  ];

  // ============================================================
  // BANGLADESH EDUCATION BOARDS
  // ============================================================

  final List<String> educationBoards = [
    'Dhaka',
    'Rajshahi',
    'Chattogram',
    'Jashore',
    'Cumilla',
    'Barishal',
    'Sylhet',
    'Dinajpur',
    'Mymensingh',
    'Madrasah',
    'Technical',
    'Cambridge / Edexcel',
    'Other',
  ];

  // ============================================================
  // CURRENT STATUS
  // ============================================================

  final List<String> statusOptions = [
    'Student',
    'Government Job',
    'Private Job',
    'Teacher',
    'Engineer',
    'Doctor',
    'Banker',
    'Lawyer',
    'Freelancer',
    'Business',
    'House Maker',
    'Other',
  ];

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final Map<int, TextEditingController> educationSubjectControllers = {};
  final Map<int, TextEditingController> educationInstitutionControllers = {};
  final Map<int, TextEditingController> educationYearControllers = {};

  final Map<int, TextEditingController> jobDesignationControllers = {};
  final Map<int, TextEditingController> jobOrganizationControllers = {};
  final Map<int, TextEditingController> jobDepartmentControllers = {};
  final Map<int, TextEditingController> jobLocationControllers = {};
  final Map<int, TextEditingController> jobStartYearControllers = {};
  final Map<int, TextEditingController> jobEndYearControllers = {};
  final Map<int, TextEditingController> jobDescriptionControllers = {};

  final Map<int, TextEditingController> businessNameControllers = {};
  final Map<int, TextEditingController> businessTypeControllers = {};
  final Map<int, TextEditingController> businessCategoryControllers = {};

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _createEducationControllers(0);
  }

  // ============================================================
  // CREATE CONTROLLERS
  // ============================================================

  void _createEducationControllers(int index) {
    educationSubjectControllers[index] = TextEditingController();
    educationInstitutionControllers[index] = TextEditingController();
    educationYearControllers[index] = TextEditingController();
  }

  void _createJobControllers(int index) {
    jobDesignationControllers[index] = TextEditingController();
    jobOrganizationControllers[index] = TextEditingController();
    jobDepartmentControllers[index] = TextEditingController();
    jobLocationControllers[index] = TextEditingController();
    jobStartYearControllers[index] = TextEditingController();
    jobEndYearControllers[index] = TextEditingController();
    jobDescriptionControllers[index] = TextEditingController();
  }

  void _createBusinessControllers(int index) {
    businessNameControllers[index] = TextEditingController();
    businessTypeControllers[index] = TextEditingController();
    businessCategoryControllers[index] = TextEditingController();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    ageController.dispose();
    for (final c in educationSubjectControllers.values) {
      c.dispose();
    }
    for (final c in educationInstitutionControllers.values) {
      c.dispose();
    }
    for (final c in educationYearControllers.values) {
      c.dispose();
    }
    for (final c in jobDesignationControllers.values) {
      c.dispose();
    }
    for (final c in jobOrganizationControllers.values) {
      c.dispose();
    }
    for (final c in jobDepartmentControllers.values) {
      c.dispose();
    }
    for (final c in jobLocationControllers.values) {
      c.dispose();
    }
    for (final c in jobStartYearControllers.values) {
      c.dispose();
    }
    for (final c in jobEndYearControllers.values) {
      c.dispose();
    }
    for (final c in jobDescriptionControllers.values) {
      c.dispose();
    }
    for (final c in businessNameControllers.values) {
      c.dispose();
    }
    for (final c in businessTypeControllers.values) {
      c.dispose();
    }
    for (final c in businessCategoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryMaroon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryMaroon, width: 1.5),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool isSchoolLevel(String degree) => [
        'SSC',
        'Dakhil',
        'O-Level',
        'SSC Vocational',
        'Secondary Equivalent',
        'Other Secondary'
      ].contains(degree);
  bool isHigherSecondary(String degree) => [
        'HSC',
        'Alim',
        'A-Level',
        'HSC Vocational',
        'Higher Secondary Equivalent',
        'Other Higher Secondary'
      ].contains(degree);
  bool requiresBoard(String degree) =>
      isSchoolLevel(degree) || isHigherSecondary(degree);

  void addEducation() {
    setState(() {
      final index = educationEntries.length;
      educationEntries.add(EducationEntry());
      _createEducationControllers(index);
    });
  }

  void removeEducation(int index) {
    if (educationEntries.length == 1) return;
    educationSubjectControllers[index]?.dispose();
    educationInstitutionControllers[index]?.dispose();
    educationYearControllers[index]?.dispose();
    educationSubjectControllers.remove(index);
    educationInstitutionControllers.remove(index);
    educationYearControllers.remove(index);
    setState(() => educationEntries.removeAt(index));
  }

  void addCurrentJob() {
    final index = currentJobs.length;
    setState(() {
      currentJobs.add(ProfessionEntry(isCurrent: true));
      _createJobControllers(index);
    });
  }

  void removeCurrentJob(int index) {
    jobDesignationControllers[index]?.dispose();
    jobOrganizationControllers[index]?.dispose();
    jobDepartmentControllers[index]?.dispose();
    jobLocationControllers[index]?.dispose();
    jobStartYearControllers[index]?.dispose();
    jobEndYearControllers[index]?.dispose();
    jobDescriptionControllers[index]?.dispose();
    setState(() => currentJobs.removeAt(index));
  }

  void addPreviousJob() {
    final index = previousJobs.length;
    setState(() {
      previousJobs.add(ProfessionEntry(isCurrent: false));
      _createJobControllers(index + 1000);
    });
  }

  void removePreviousJob(int index) {
    final controllerIndex = index + 1000;
    jobDesignationControllers[controllerIndex]?.dispose();
    jobOrganizationControllers[controllerIndex]?.dispose();
    jobDepartmentControllers[controllerIndex]?.dispose();
    jobLocationControllers[controllerIndex]?.dispose();
    jobStartYearControllers[controllerIndex]?.dispose();
    jobEndYearControllers[controllerIndex]?.dispose();
    jobDescriptionControllers[controllerIndex]?.dispose();
    setState(() => previousJobs.removeAt(index));
  }

  void syncEducationData() {
    for (int i = 0; i < educationEntries.length; i++) {
      final entry = educationEntries[i];
      entry.subject = educationSubjectControllers[i]?.text.trim() ?? '';
      entry.institution = educationInstitutionControllers[i]?.text.trim() ?? '';
      entry.year = educationYearControllers[i]?.text.trim() ?? '';
    }
  }

  void syncJobData() {
    for (int i = 0; i < currentJobs.length; i++) {
      final job = currentJobs[i];
      job.designation = jobDesignationControllers[i]?.text.trim() ?? '';
      job.organization = jobOrganizationControllers[i]?.text.trim() ?? '';
      job.department = jobDepartmentControllers[i]?.text.trim() ?? '';
      job.location = jobLocationControllers[i]?.text.trim() ?? '';
      job.startYear = jobStartYearControllers[i]?.text.trim() ?? '';
      job.endYear = jobEndYearControllers[i]?.text.trim() ?? '';
      job.description = jobDescriptionControllers[i]?.text.trim() ?? '';
    }

    for (int i = 0; i < previousJobs.length; i++) {
      final controllerIndex = i + 1000;
      final job = previousJobs[i];
      job.designation =
          jobDesignationControllers[controllerIndex]?.text.trim() ?? '';
      job.organization =
          jobOrganizationControllers[controllerIndex]?.text.trim() ?? '';
      job.department =
          jobDepartmentControllers[controllerIndex]?.text.trim() ?? '';
      job.location = jobLocationControllers[controllerIndex]?.text.trim() ?? '';
      job.startYear =
          jobStartYearControllers[controllerIndex]?.text.trim() ?? '';
      job.endYear = jobEndYearControllers[controllerIndex]?.text.trim() ?? '';
      job.description =
          jobDescriptionControllers[controllerIndex]?.text.trim() ?? '';
    }
  }

  String getEducationSummary() {
    syncEducationData();
    final validEntries = educationEntries
        .where((e) =>
            e.degree.trim().isNotEmpty || e.institution.trim().isNotEmpty)
        .toList();
    if (validEntries.isEmpty) return 'Not specified';
    return validEntries.map((e) {
      String text = e.degree;
      if (e.subject.isNotEmpty) text += ' - ${e.subject}';
      if (e.institution.isNotEmpty) text += ' - ${e.institution}';
      if (e.year.isNotEmpty)
        text += e.currentlyStudying ? ' (Expected ${e.year})' : ' (${e.year})';
      return text;
    }).join('\n');
  }

  String getProfessionSummary() {
    syncJobData();
    final List<String> result = [];
    if (currentStatus != null) result.add(currentStatus!);
    for (final job in currentJobs) {
      if (job.type.isNotEmpty) {
        String text = job.type;
        if (job.designation.isNotEmpty) text += ' - ${job.designation}';
        if (job.organization.isNotEmpty) text += ' - ${job.organization}';
        result.add(text);
      }
    }
    if (result.isEmpty) return 'Not specified';
    return result.join('\n');
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    if (district == null || maritalStatus == null) {
      _snack(widget.isBangla
          ? 'জেলা এবং বৈবাহিক অবস্থা নির্বাচন করুন।'
          : 'Please select district and marital status.');
      return;
    }

    if (currentStatus == null) {
      _snack(widget.isBangla
          ? 'আপনার বর্তমান অবস্থা নির্বাচন করুন।'
          : 'Please select your current status.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _snack('Not logged in');
      return;
    }

    syncEducationData();
    syncJobData();

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        // ✅ FIX: gender ও religion যোগ করা হলো (বাকি সব অপরিবর্তিত)
        'gender': widget.gender,
        'religion': widget.religion,
        'age': ageController.text.trim(),
        'district': district ?? '',
        'maritalStatus': maritalStatus ?? '',
        'height': height ?? '',
        'skinTone': skinTone ?? '',
        'currentStatus': currentStatus ?? '',
        'education': getEducationSummary(),
        'profession': getProfessionSummary(),
        'educationEntries': educationEntries
            .map((e) => {
                  'degree': e.degree,
                  'board': e.board,
                  'subject': e.subject,
                  'institution': e.institution,
                  'year': e.year,
                  'currentlyStudying': e.currentlyStudying,
                })
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ [ProfileSetup] Data saved for $uid');
    } catch (e) {
      debugPrint('❌ [ProfileSetup] Save failed: $e');
      _snack(widget.isBangla
          ? 'সেভ করা যায়নি। আবার চেষ্টা করুন।'
          : 'Could not save. Try again.');
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailsScreen(
          isBangla: widget.isBangla,
          name: widget.name,
          gender: widget.gender,
          religion: widget.religion,
          email: widget.email,
          phone: widget.phone,
          age: ageController.text.trim(),
          district: district!,
          maritalStatus: maritalStatus!,
          education: getEducationSummary(),
          profession: getProfessionSummary(),
          height: height ?? '',
          skinTone: skinTone ?? '',
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryMaroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // REUSABLE WIDGETS
  // ============================================================

  Widget buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: fieldDecoration(label: label, icon: icon),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(item.toString(), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget buildEducationCard(int index) {
    final entry = educationEntries[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DCEA)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: lightMaroon,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.school_rounded, color: primaryMaroon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Education ${index + 1}',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: mainText)),
              ),
              if (educationEntries.length > 1)
                IconButton(
                  onPressed: () => removeEducation(index),
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 16),
          buildDropdown<String>(
            label: 'Degree / Qualification',
            icon: Icons.workspace_premium_outlined,
            value: entry.degree.isEmpty ? null : entry.degree,
            items: educationDegrees,
            onChanged: (value) {
              setState(() {
                entry.degree = value ?? '';
                if (!requiresBoard(entry.degree)) entry.board = '';
              });
            },
          ),
          const SizedBox(height: 14),
          if (requiresBoard(entry.degree)) ...[
            buildDropdown<String>(
              label: 'Education Board',
              icon: Icons.account_balance_outlined,
              value: entry.board.isEmpty ? null : entry.board,
              items: educationBoards,
              onChanged: (value) => setState(() => entry.board = value ?? ''),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: educationSubjectControllers[index],
            decoration: fieldDecoration(
                label: 'Subject / Major / Department',
                icon: Icons.menu_book_outlined,
                hint: 'e.g. Computer Science & Technology'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: educationInstitutionControllers[index],
            decoration: fieldDecoration(
                label: 'Institution',
                icon: Icons.account_balance,
                hint: 'School / College / University'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: entry.currentlyStudying,
                activeColor: primaryMaroon,
                onChanged: (value) =>
                    setState(() => entry.currentlyStudying = value ?? false),
              ),
              Expanded(
                child: Text(
                  widget.isBangla
                      ? 'আমি বর্তমানে এখানে পড়াশোনা করছি'
                      : 'I am currently studying here',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: mainText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: educationYearControllers[index],
            keyboardType: TextInputType.number,
            decoration: fieldDecoration(
              label: entry.currentlyStudying
                  ? 'Expected Completion Year'
                  : 'Passing Year',
              icon: Icons.calendar_month_outlined,
              hint: 'e.g. 2027',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget buildJobCard(
      {required int index,
      required ProfessionEntry job,
      required bool isCurrent}) {
    final controllerIndex = isCurrent ? index : index + 1000;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DCEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline, color: primaryMaroon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCurrent
                      ? 'Current Job ${index + 1}'
                      : 'Previous Job ${index + 1}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: mainText),
                ),
              ),
              IconButton(
                onPressed: () => isCurrent
                    ? removeCurrentJob(index)
                    : removePreviousJob(index),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildDropdown<String>(
            label: 'Job Type',
            icon: Icons.badge_outlined,
            value: job.type.isEmpty ? null : job.type,
            items: [
              'Government Job',
              'Private Job',
              'Teacher',
              'Engineer',
              'Doctor',
              'Banker',
              'Lawyer',
              'Freelancer',
              'Other'
            ],
            onChanged: (value) => setState(() => job.type = value ?? ''),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobDesignationControllers[controllerIndex],
            decoration: fieldDecoration(
                label: 'Designation',
                icon: Icons.person_outline,
                hint: 'e.g. Instructor'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobOrganizationControllers[controllerIndex],
            decoration: fieldDecoration(
                label: 'Organization',
                icon: Icons.business_outlined,
                hint: 'Company / Institution'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobDepartmentControllers[controllerIndex],
            decoration: fieldDecoration(
                label: 'Department',
                icon: Icons.account_tree_outlined,
                hint: 'Optional'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobLocationControllers[controllerIndex],
            decoration: fieldDecoration(
                label: 'Job Location',
                icon: Icons.location_on_outlined,
                hint: 'e.g. Dhaka'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: jobStartYearControllers[controllerIndex],
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration(
                      label: 'Start Year', icon: Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: jobEndYearControllers[controllerIndex],
                  keyboardType: TextInputType.number,
                  decoration: fieldDecoration(
                      label: isCurrent ? 'Present' : 'End Year',
                      icon: Icons.event_outlined),
                  enabled: !isCurrent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: jobDescriptionControllers[controllerIndex],
            maxLines: 3,
            decoration: fieldDecoration(
                label: 'Job Description',
                icon: Icons.description_outlined,
                hint: 'Optional'),
          ),
        ],
      ),
    );
  }

  Widget buildBusinessCard() {
    if (businessNameControllers[9999] == null) _createBusinessControllers(9999);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4DCEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_outlined, color: primaryMaroon),
              SizedBox(width: 10),
              Text('Business Details',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: mainText)),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: businessNameControllers[9999],
            decoration: fieldDecoration(
                label: 'Business Name', icon: Icons.store_outlined),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: businessTypeControllers[9999],
            decoration: fieldDecoration(
                label: 'Business Type',
                icon: Icons.business_center_outlined,
                hint: 'e.g. Online Business'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: businessCategoryControllers[9999],
            decoration: fieldDecoration(
                label: 'Business Category',
                icon: Icons.category_outlined,
                hint: 'e.g. Electronics'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            decoration: fieldDecoration(
                label: 'Business Location', icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 14),
          TextFormField(
            maxLines: 3,
            decoration: fieldDecoration(
                label: 'Business Description',
                icon: Icons.description_outlined),
          ),
        ],
      ),
    );
  }

  Widget sectionHeader(
      {required IconData icon, required String title, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: lightMaroon, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: primaryMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: mainText)),
                if (subtitle != null)
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 13, color: secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget addButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_circle_outline),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryMaroon,
          side: const BorderSide(color: primaryMaroon, width: 1.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD (Responsive Layout Switcher)
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🌐 ওয়েব বা বড় স্ক্রিনের জন্য (900px এর বেশি)
        if (constraints.maxWidth > 900) {
          return _buildWebLayout();
        }
        // 📱 মোবাইলের জন্য (আপনার অরিজিনাল কোড)
        return _buildMobileLayout();
      },
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (Original Code - Untouched)
  // ============================================================
  Widget _buildMobileLayout() {
    final bool isBusiness = currentStatus == 'Business';

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isBangla ? 'প্রোফাইল সেটআপ' : 'Profile Setup',
          style:
              const TextStyle(color: deepMaroon, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              // ==================================================
              // PROGRESS
              // ==================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [primaryMaroon, deepMaroon]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isBangla
                                ? 'আপনার সম্পর্কে আরও তথ্য দিন'
                                : 'Tell us more about yourself',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isBangla
                                ? 'এই তথ্যগুলো আপনার ম্যাচিং আরও নির্ভুল করতে সাহায্য করবে।'
                                : 'These details will help improve your matching.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ==================================================
              // BASIC INFORMATION
              // ==================================================
              sectionHeader(
                  icon: Icons.person_pin_outlined,
                  title: widget.isBangla ? 'মৌলিক তথ্য' : 'Basic Information'),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                    label: widget.isBangla ? 'বয়স' : 'Age',
                    icon: Icons.cake_outlined,
                    hint: 'e.g. 28'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  final age = int.tryParse(value.trim());
                  if (age == null || age < 18 || age > 100)
                    return 'Enter a valid age';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              buildDropdown<String>(
                label: widget.isBangla ? 'জেলা' : 'District',
                icon: Icons.location_on_outlined,
                value: district,
                items: districts,
                onChanged: (value) => setState(() => district = value),
              ),
              const SizedBox(height: 14),
              buildDropdown<String>(
                label: widget.isBangla ? 'বৈবাহিক অবস্থা' : 'Marital Status',
                icon: Icons.favorite_border,
                value: maritalStatus,
                items: maritalStatuses,
                onChanged: (value) => setState(() => maritalStatus = value),
              ),
              const SizedBox(height: 14),
              buildDropdown<String>(
                label: widget.isBangla ? 'উচ্চতা' : 'Height',
                icon: Icons.height,
                value: height,
                items: const [
                  "4'6\"",
                  "4'7\"",
                  "4'8\"",
                  "4'9\"",
                  "4'10\"",
                  "4'11\"",
                  "5'0\"",
                  "5'1\"",
                  "5'2\"",
                  "5'3\"",
                  "5'4\"",
                  "5'5\"",
                  "5'6\"",
                  "5'7\"",
                  "5'8\"",
                  "5'9\"",
                  "5'10\"",
                  "5'11\"",
                  "6'0\"",
                  "6'1\"",
                  "6'2\"",
                  "6'3\"",
                  "6'4\"",
                  "6'5\"",
                  "6'6\"",
                  "6'7\"",
                  "6'8\"",
                  "6'9\"",
                  "6'10\"",
                  "6'11\"",
                  "7'0\""
                ],
                onChanged: (value) => setState(() => height = value),
              ),
              const SizedBox(height: 14),
              buildDropdown<String>(
                label: widget.isBangla ? 'গায়ের রং' : 'Skin Tone',
                icon: Icons.color_lens_outlined,
                value: skinTone,
                items: const [
                  'Very Fair (উজ্জ্বল ফর্সা)',
                  'Fair (ফর্সা)',
                  'Wheatish (উজ্জ্বল শ্যামলা)',
                  'Medium (শ্যামলা)',
                  'Dark (কালো)'
                ],
                onChanged: (value) => setState(() => skinTone = value),
              ),

              // ==================================================
              // EDUCATION
              // ==================================================
              const SizedBox(height: 18),
              sectionHeader(
                icon: Icons.school_outlined,
                title: widget.isBangla ? 'শিক্ষাগত যোগ্যতা' : 'Education',
                subtitle: widget.isBangla
                    ? 'SSC থেকে PhD পর্যন্ত একাধিক যোগ্যতা যোগ করতে পারবেন'
                    : 'Add multiple qualifications from SSC to PhD',
              ),
              ...List.generate(educationEntries.length,
                  (index) => buildEducationCard(index)),
              addButton(
                  text: widget.isBangla
                      ? 'আরও শিক্ষা যোগ করুন'
                      : 'Add More Education',
                  onPressed: addEducation),

              // ==================================================
              // PROFESSION
              // ==================================================
              const SizedBox(height: 24),
              sectionHeader(
                icon: Icons.work_outline,
                title: widget.isBangla ? 'পেশাগত তথ্য' : 'Profession & Career',
                subtitle: widget.isBangla
                    ? 'আপনার বর্তমান পেশা নির্বাচন করুন'
                    : 'Select your current professional status',
              ),
              buildDropdown<String>(
                label: widget.isBangla ? 'বর্তমান অবস্থা' : 'Current Status',
                icon: Icons.work_history_outlined,
                value: currentStatus,
                items: statusOptions,
                onChanged: (value) {
                  setState(() {
                    currentStatus = value;
                    if (value == 'Business' &&
                        businessNameControllers[9999] == null) {
                      _createBusinessControllers(9999);
                    }
                  });
                },
              ),

              if (currentStatus == 'Student')
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE4DCEA))),
                  child: Column(
                    children: [
                      const Row(children: [
                        Icon(Icons.school_outlined, color: primaryMaroon),
                        SizedBox(width: 10),
                        Text('Current Study Details',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: mainText))
                      ]),
                      const SizedBox(height: 16),
                      TextFormField(
                          decoration: fieldDecoration(
                              label: 'Current Institution',
                              icon: Icons.account_balance_outlined)),
                      const SizedBox(height: 14),
                      TextFormField(
                          decoration: fieldDecoration(
                              label: 'Degree / Program',
                              icon: Icons.school_outlined)),
                      const SizedBox(height: 14),
                      TextFormField(
                          decoration: fieldDecoration(
                              label: 'Subject / Department',
                              icon: Icons.menu_book_outlined)),
                      const SizedBox(height: 14),
                      TextFormField(
                          decoration: fieldDecoration(
                              label: 'Current Year / Semester',
                              icon: Icons.calendar_view_month_outlined)),
                      const SizedBox(height: 14),
                      TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: fieldDecoration(
                              label: 'Expected Completion Year',
                              icon: Icons.event_available_outlined,
                              hint: 'e.g. 2027')),
                    ],
                  ),
                ),

              if (isBusiness) buildBusinessCard(),

              if (currentStatus == 'House Maker')
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: lightGold,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: primaryGold.withValues(alpha: 0.4))),
                  child: const Row(children: [
                    Icon(Icons.home_outlined, color: deepGold, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('House Maker',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: mainText)))
                  ]),
                ),

              if (currentStatus != null &&
                  currentStatus != 'Student' &&
                  currentStatus != 'Business' &&
                  currentStatus != 'House Maker') ...[
                const SizedBox(height: 16),
                ...List.generate(
                    currentJobs.length,
                    (index) => buildJobCard(
                        index: index,
                        job: currentJobs[index],
                        isCurrent: true)),
                addButton(
                    text: widget.isBangla
                        ? 'আরও বর্তমান চাকরি যোগ করুন'
                        : 'Add Another Current Job',
                    onPressed: addCurrentJob),
              ],

              if (currentStatus == 'Business') ...[
                const SizedBox(height: 16),
                ...List.generate(
                    currentJobs.length,
                    (index) => buildJobCard(
                        index: index,
                        job: currentJobs[index],
                        isCurrent: true)),
                addButton(
                    text: widget.isBangla
                        ? 'আরও বর্তমান পেশা যোগ করুন'
                        : 'Add Another Current Profession',
                    onPressed: addCurrentJob),
              ],

              // ==================================================
              // PREVIOUS JOBS
              // ==================================================
              const SizedBox(height: 24),
              sectionHeader(
                icon: Icons.history_outlined,
                title: widget.isBangla
                    ? 'পূর্বের চাকরি / পেশা'
                    : 'Previous Jobs / Careers',
                subtitle: widget.isBangla
                    ? 'আগের চাকরি বা পেশার তথ্য চাইলে যোগ করুন'
                    : 'Add your previous jobs or careers if applicable',
              ),
              ...List.generate(
                  previousJobs.length,
                  (index) => buildJobCard(
                      index: index,
                      job: previousJobs[index],
                      isCurrent: false)),
              addButton(
                  text: widget.isBangla
                      ? 'পূর্বের চাকরি যোগ করুন'
                      : 'Add Previous Job',
                  onPressed: addPreviousJob),

              // ==================================================
              // CONTINUE BUTTON
              // ==================================================
              const SizedBox(height: 30),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.isBangla ? 'পরবর্তী ধাপে যান' : 'Continue',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম ডিজাইন)
  // ============================================================
  Widget _buildWebLayout() {
    final bool isBusiness = currentStatus == 'Business';

    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F6F9), // ওয়েবের জন্য হালকা গ্রে ব্যাকগ্রাউন্ড
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        title: Text(
          widget.isBangla ? 'প্রোফাইল সেটআপ' : 'Profile Setup',
          style:
              const TextStyle(color: deepMaroon, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 1200), // ওয়েবের ম্যাক্স উইডথ
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Banner (Full Width)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [primaryMaroon, deepMaroon]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: primaryMaroon.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10))
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              color: Colors.white, size: 40),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.isBangla
                                      ? 'আপনার সম্পর্কে আরও তথ্য দিন'
                                      : 'Tell us more about yourself',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.isBangla
                                      ? 'এই তথ্যগুলো আপনার ম্যাচিং আরও নির্ভুল করতে সাহায্য করবে।'
                                      : 'These details will help improve your matching.',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // দুই কলামের গ্রিড
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔴 বাম কলাম (Basic Info & Education)
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sectionHeader(
                                  icon: Icons.person_pin_outlined,
                                  title: widget.isBangla
                                      ? 'মৌলিক তথ্য'
                                      : 'Basic Information'),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: ageController,
                                      keyboardType: TextInputType.number,
                                      decoration: fieldDecoration(
                                          label:
                                              widget.isBangla ? 'বয়স' : 'Age',
                                          icon: Icons.cake_outlined,
                                          hint: 'e.g. 28'),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty)
                                          return 'Required';
                                        final age = int.tryParse(value.trim());
                                        if (age == null ||
                                            age < 18 ||
                                            age > 100)
                                          return 'Enter a valid age';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildDropdown<String>(
                                      label:
                                          widget.isBangla ? 'জেলা' : 'District',
                                      icon: Icons.location_on_outlined,
                                      value: district,
                                      items: districts,
                                      onChanged: (value) =>
                                          setState(() => district = value),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildDropdown<String>(
                                      label: widget.isBangla
                                          ? 'বৈবাহিক অবস্থা'
                                          : 'Marital Status',
                                      icon: Icons.favorite_border,
                                      value: maritalStatus,
                                      items: maritalStatuses,
                                      onChanged: (value) =>
                                          setState(() => maritalStatus = value),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: buildDropdown<String>(
                                      label:
                                          widget.isBangla ? 'উচ্চতা' : 'Height',
                                      icon: Icons.height,
                                      value: height,
                                      items: const [
                                        "4'6\"",
                                        "4'7\"",
                                        "4'8\"",
                                        "4'9\"",
                                        "4'10\"",
                                        "4'11\"",
                                        "5'0\"",
                                        "5'1\"",
                                        "5'2\"",
                                        "5'3\"",
                                        "5'4\"",
                                        "5'5\"",
                                        "5'6\"",
                                        "5'7\"",
                                        "5'8\"",
                                        "5'9\"",
                                        "5'10\"",
                                        "5'11\"",
                                        "6'0\"",
                                        "6'1\"",
                                        "6'2\"",
                                        "6'3\"",
                                        "6'4\"",
                                        "6'5\"",
                                        "6'6\"",
                                        "6'7\"",
                                        "6'8\"",
                                        "6'9\"",
                                        "6'10\"",
                                        "6'11\"",
                                        "7'0\""
                                      ],
                                      onChanged: (value) =>
                                          setState(() => height = value),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              buildDropdown<String>(
                                label:
                                    widget.isBangla ? 'গায়ের রং' : 'Skin Tone',
                                icon: Icons.color_lens_outlined,
                                value: skinTone,
                                items: const [
                                  'Very Fair (উজ্জ্বল ফর্সা)',
                                  'Fair (ফর্সা)',
                                  'Wheatish (উজ্জ্বল শ্যামলা)',
                                  'Medium (শ্যামলা)',
                                  'Dark (কালো)'
                                ],
                                onChanged: (value) =>
                                    setState(() => skinTone = value),
                              ),
                              const SizedBox(height: 30),
                              sectionHeader(
                                icon: Icons.school_outlined,
                                title: widget.isBangla
                                    ? 'শিক্ষাগত যোগ্যতা'
                                    : 'Education',
                                subtitle: widget.isBangla
                                    ? 'SSC থেকে PhD পর্যন্ত একাধিক যোগ্যতা যোগ করতে পারবেন'
                                    : 'Add multiple qualifications from SSC to PhD',
                              ),
                              ...List.generate(educationEntries.length,
                                  (index) => buildEducationCard(index)),
                              addButton(
                                  text: widget.isBangla
                                      ? 'আরও শিক্ষা যোগ করুন'
                                      : 'Add More Education',
                                  onPressed: addEducation),
                            ],
                          ),
                        ),

                        // মাঝখানে গ্যাপ
                        const SizedBox(width: 40),

                        // 🟢 ডান কলাম (Profession)
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              sectionHeader(
                                icon: Icons.work_outline,
                                title: widget.isBangla
                                    ? 'পেশাগত তথ্য'
                                    : 'Profession & Career',
                                subtitle: widget.isBangla
                                    ? 'আপনার বর্তমান পেশা নির্বাচন করুন'
                                    : 'Select your current professional status',
                              ),
                              buildDropdown<String>(
                                label: widget.isBangla
                                    ? 'বর্তমান অবস্থা'
                                    : 'Current Status',
                                icon: Icons.work_history_outlined,
                                value: currentStatus,
                                items: statusOptions,
                                onChanged: (value) {
                                  setState(() {
                                    currentStatus = value;
                                    if (value == 'Business' &&
                                        businessNameControllers[9999] == null) {
                                      _createBusinessControllers(9999);
                                    }
                                  });
                                },
                              ),
                              if (currentStatus == 'Student')
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                          color: const Color(0xFFE4DCEA))),
                                  child: Column(
                                    children: [
                                      const Row(children: [
                                        Icon(Icons.school_outlined,
                                            color: primaryMaroon),
                                        SizedBox(width: 10),
                                        Text('Current Study Details',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: mainText))
                                      ]),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                          decoration: fieldDecoration(
                                              label: 'Current Institution',
                                              icon: Icons
                                                  .account_balance_outlined)),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                          decoration: fieldDecoration(
                                              label: 'Degree / Program',
                                              icon: Icons.school_outlined)),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                          decoration: fieldDecoration(
                                              label: 'Subject / Department',
                                              icon: Icons.menu_book_outlined)),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                          decoration: fieldDecoration(
                                              label: 'Current Year / Semester',
                                              icon: Icons
                                                  .calendar_view_month_outlined)),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                          keyboardType: TextInputType.number,
                                          decoration: fieldDecoration(
                                              label: 'Expected Completion Year',
                                              icon: Icons
                                                  .event_available_outlined,
                                              hint: 'e.g. 2027')),
                                    ],
                                  ),
                                ),
                              if (isBusiness) buildBusinessCard(),
                              if (currentStatus == 'House Maker')
                                Container(
                                  margin: const EdgeInsets.only(top: 16),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                      color: lightGold,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: primaryGold.withValues(
                                              alpha: 0.4))),
                                  child: const Row(children: [
                                    Icon(Icons.home_outlined,
                                        color: deepGold, size: 30),
                                    SizedBox(width: 12),
                                    Expanded(
                                        child: Text('House Maker',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: mainText)))
                                  ]),
                                ),
                              if (currentStatus != null &&
                                  currentStatus != 'Student' &&
                                  currentStatus != 'Business' &&
                                  currentStatus != 'House Maker') ...[
                                const SizedBox(height: 16),
                                ...List.generate(
                                    currentJobs.length,
                                    (index) => buildJobCard(
                                        index: index,
                                        job: currentJobs[index],
                                        isCurrent: true)),
                                addButton(
                                    text: widget.isBangla
                                        ? 'আরও বর্তমান চাকরি যোগ করুন'
                                        : 'Add Another Current Job',
                                    onPressed: addCurrentJob),
                              ],
                              if (currentStatus == 'Business') ...[
                                const SizedBox(height: 16),
                                ...List.generate(
                                    currentJobs.length,
                                    (index) => buildJobCard(
                                        index: index,
                                        job: currentJobs[index],
                                        isCurrent: true)),
                                addButton(
                                    text: widget.isBangla
                                        ? 'আরও বর্তমান পেশা যোগ করুন'
                                        : 'Add Another Current Profession',
                                    onPressed: addCurrentJob),
                              ],
                              const SizedBox(height: 30),
                              sectionHeader(
                                icon: Icons.history_outlined,
                                title: widget.isBangla
                                    ? 'পূর্বের চাকরি / পেশা'
                                    : 'Previous Jobs / Careers',
                                subtitle: widget.isBangla
                                    ? 'আগের চাকরি বা পেশার তথ্য চাইলে যোগ করুন'
                                    : 'Add your previous jobs or careers if applicable',
                              ),
                              ...List.generate(
                                  previousJobs.length,
                                  (index) => buildJobCard(
                                      index: index,
                                      job: previousJobs[index],
                                      isCurrent: false)),
                              addButton(
                                  text: widget.isBangla
                                      ? 'পূর্বের চাকরি যোগ করুন'
                                      : 'Add Previous Job',
                                  onPressed: addPreviousJob),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // সাবমিট বাটন (সেন্টারে)
                    Center(
                      child: SizedBox(
                        width: 400,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: primaryMaroon.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  widget.isBangla
                                      ? 'পরবর্তী ধাপে যান'
                                      : 'Continue',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
