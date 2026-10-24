import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ✅ Deferred Loading Import for ProfilePreviewScreen
import 'profile_preview_screen.dart' deferred as profile_preview_lib;

// ============================================================
// PROFILE DETAILS SCREEN
// ============================================================

class ProfileDetailsScreen extends StatefulWidget {
  final bool isBangla;

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
  final String height;
  final String skinTone;

  const ProfileDetailsScreen({
    super.key,
    required this.isBangla,
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
    required this.height,
    required this.skinTone,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final formKey = GlobalKey<FormState>();

  // ============================================================
  // PROFILE PHOTOS
  // ============================================================

  File? profileImage; // main photo
  List<File> additionalImages = []; // additional photos (max 5)

  final ImagePicker imagePicker = ImagePicker();

  // ============================================================
  // ABOUT ME
  // ============================================================

  final aboutController = TextEditingController();

  // ============================================================
  // PARTNER PREFERENCE
  // ============================================================

  String? preferredAge;
  String? preferredReligion;
  String? preferredEducation;
  String? preferredProfession;

  // ============================================================
  // DATA
  // ============================================================

  final List<String> preferredAgeOptions = [
    '18 - 22',
    '23 - 27',
    '28 - 32',
    '33 - 37',
    '38 - 42',
    '43 - 50',
    'Any Age',
  ];

  final List<String> religionOptions = [
    'Islam',
    'Hinduism',
    'Christianity',
    'Buddhism',
    'Other',
    'Any Religion',
  ];

  final List<String> educationOptions = [
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
    'Any Education',
  ];

  final List<String> professionOptions = [
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
    'Any Profession',
  ];

  // ============================================================
  // IMAGE PICKERS
  // ============================================================

  Future<void> pickProfileImage() async {
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (image == null) return;

    setState(() {
      profileImage = File(image.path);
    });
  }

  Future<void> pickAdditionalImage() async {
    if (additionalImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isBangla
                ? 'সর্বোচ্চ ৫টা ছবি যোগ করা যাবে।'
                : 'You can add up to 5 photos.',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final XFile? picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (picked == null) return;

    setState(() {
      additionalImages.add(File(picked.path));
    });
  }

  void removeAdditionalImage(int index) {
    setState(() {
      additionalImages.removeAt(index);
    });
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
    );
  }

  Widget sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
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

  Widget infoRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE4DCEA)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: primaryMaroon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: secondaryText)),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: mainText),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTINUE (With Deferred Loading for Preview Screen)
  // ============================================================
  Future<void> continueProfile() async {
    if (!formKey.currentState!.validate()) return;

    if (profileImage == null) {
      _snack(widget.isBangla
          ? 'অনুগ্রহ করে একটি প্রোফাইল ছবি নির্বাচন করুন।'
          : 'Please select a profile photo.');
      return;
    }

    if (preferredAge == null ||
        preferredReligion == null ||
        preferredEducation == null ||
        preferredProfession == null) {
      _snack(widget.isBangla
          ? 'সব Partner Preference নির্বাচন করুন।'
          : 'Please select all partner preferences.');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'aboutMe': aboutController.text.trim(),
        'preferredAge': preferredAge ?? '',
        'preferredReligion': preferredReligion ?? '',
        'preferredEducation': preferredEducation ?? '',
        'preferredProfession': preferredProfession ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ [ProfileDetails] Data saved for $uid');
    } catch (e) {
      debugPrint('❌ [ProfileDetails] Save failed: $e');
      _snack(widget.isBangla ? 'সেভ করা যায়নি।' : 'Could not save.');
      return;
    }

    if (!mounted) return;

    // ✅ Show Loading Dialog while loading deferred library
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await profile_preview_lib.loadLibrary();

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => profile_preview_lib.ProfilePreviewScreen(
          isBangla: widget.isBangla,
          name: widget.name,
          gender: widget.gender,
          religion: widget.religion,
          email: widget.email,
          phone: widget.phone,
          age: widget.age,
          district: widget.district,
          maritalStatus: widget.maritalStatus,
          education: widget.education,
          profession: widget.profession,
          height: widget.height,
          skinTone: widget.skinTone,
          profileImage: profileImage,
          additionalImages: additionalImages,
          aboutMe: aboutController.text.trim(),
          preferredAge: preferredAge!,
          about: aboutController.text.trim(),
          preferredReligion: preferredReligion!,
          preferredEducation: preferredEducation!,
          preferredProfession: preferredProfession!,
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

  @override
  void dispose() {
    aboutController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD (Responsive Layout Switcher)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isBangla ? 'প্রোফাইল বিস্তারিত' : 'Profile Details',
          style:
              const TextStyle(color: deepMaroon, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return Column(
            children: [
              Expanded(
                child: Form(
                  key: formKey,
                  child: isDesktop ? _buildWebLayout() : _buildMobileLayout(),
                ),
              ),
              // ✅ AdMob শুধু মোবাইলে
              if (!kIsWeb)
                const SafeArea(
                  top: false,
                  child: BannerAdWidget(
                      placementId: AdConfig.placementProfileView),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          sectionHeader(
            icon: Icons.photo_camera_outlined,
            title: widget.isBangla ? 'প্রোফাইল ছবি' : 'Profile Photo',
            subtitle: widget.isBangla
                ? 'আপনার একটি পরিষ্কার ছবি দিন'
                : 'Add a clear profile photo',
          ),
          Center(
            child: GestureDetector(
              onTap: pickProfileImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightMaroon,
                  border: Border.all(color: primaryGold, width: 3),
                ),
                child: ClipOval(
                  child: profileImage != null
                      ? (kIsWeb
                          ? AppNetworkImage(profileImage!.path,
                              fit: BoxFit.cover,
                              width: 150,
                              height: 150,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 75,
                                  color: primaryMaroon))
                          : Image.file(profileImage!,
                              fit: BoxFit.cover, width: 150, height: 150))
                      : const Icon(Icons.person,
                          size: 75, color: primaryMaroon),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: pickProfileImage,
              icon: const Icon(Icons.camera_alt_outlined, color: primaryMaroon),
              label: Text(
                profileImage != null
                    ? (widget.isBangla ? 'ছবি পরিবর্তন করুন' : 'Change Photo')
                    : (widget.isBangla ? 'ছবি নির্বাচন করুন' : 'Choose Photo'),
                style: const TextStyle(
                    color: primaryMaroon, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          sectionHeader(
            icon: Icons.photo_library_outlined,
            title: widget.isBangla ? 'আরো ছবি' : 'More Photos',
            subtitle: widget.isBangla
                ? 'সর্বোচ্চ ৫টা ছবি যোগ করুন (${additionalImages.length}/5)'
                : 'Add up to 5 more photos (${additionalImages.length}/5)',
          ),
          const SizedBox(height: 4),
          _buildAdditionalImagesList(),
          const SizedBox(height: 16),
          sectionHeader(
            icon: Icons.person_outline,
            title: widget.isBangla ? 'আপনার তথ্য' : 'Your Information',
          ),
          infoRow('Name', widget.name, Icons.person_outline),
          infoRow('Gender', widget.gender, Icons.wc_outlined),
          infoRow('Religion', widget.religion, Icons.auto_awesome_outlined),
          infoRow('Age', widget.age, Icons.cake_outlined),
          infoRow('District', widget.district, Icons.location_on_outlined),
          infoRow(
              'Marital Status', widget.maritalStatus, Icons.favorite_border),
          sectionHeader(
            icon: Icons.edit_note_outlined,
            title: widget.isBangla ? 'আমার সম্পর্কে' : 'About Me',
            subtitle: widget.isBangla
                ? 'নিজের সম্পর্কে সংক্ষেপে লিখুন'
                : 'Tell something about yourself',
          ),
          TextFormField(
            controller: aboutController,
            maxLines: 7,
            maxLength: 500,
            decoration: fieldDecoration(
              label: widget.isBangla ? 'আমার সম্পর্কে' : 'About Me',
              icon: Icons.person_pin_outlined,
              hint: widget.isBangla
                  ? 'আপনার ব্যক্তিত্ব, পছন্দ, লক্ষ্য ইত্যাদি লিখুন...'
                  : 'Write about your personality, interests and goals...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Please write something about yourself';
              if (value.trim().length < 20)
                return 'Please write at least 20 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          sectionHeader(
            icon: Icons.favorite_outline,
            title: widget.isBangla ? 'জীবনসঙ্গীর পছন্দ' : 'Partner Preference',
            subtitle: widget.isBangla
                ? 'আপনার পছন্দের জীবনসঙ্গী সম্পর্কে জানান'
                : 'Tell us what you prefer in a partner',
          ),
          buildDropdown<String>(
            label: widget.isBangla ? 'পছন্দের বয়স' : 'Preferred Age',
            icon: Icons.cake_outlined,
            value: preferredAge,
            items: preferredAgeOptions,
            onChanged: (value) => setState(() => preferredAge = value),
          ),
          const SizedBox(height: 14),
          buildDropdown<String>(
            label: widget.isBangla ? 'পছন্দের ধর্ম' : 'Preferred Religion',
            icon: Icons.auto_awesome_outlined,
            value: preferredReligion,
            items: religionOptions,
            onChanged: (value) => setState(() => preferredReligion = value),
          ),
          const SizedBox(height: 14),
          buildDropdown<String>(
            label: widget.isBangla
                ? 'পছন্দের শিক্ষাগত যোগ্যতা'
                : 'Preferred Education',
            icon: Icons.school_outlined,
            value: preferredEducation,
            items: educationOptions,
            onChanged: (value) => setState(() => preferredEducation = value),
          ),
          const SizedBox(height: 14),
          buildDropdown<String>(
            label: widget.isBangla ? 'পছন্দের পেশা' : 'Preferred Profession',
            icon: Icons.work_outline,
            value: preferredProfession,
            items: professionOptions,
            onChanged: (value) => setState(() => preferredProfession = value),
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: continueProfile,
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
                  Text(
                    widget.isBangla
                        ? 'প্রোফাইল Preview দেখুন'
                        : 'Preview Profile',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম টু-কলাম ডিজাইন)
  // ============================================================
  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔴 বাম কলাম (ছবি ও বেসিক ইনফো)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionHeader(
                        icon: Icons.photo_camera_outlined,
                        title:
                            widget.isBangla ? 'প্রোফাইল ছবি' : 'Profile Photo',
                        subtitle: widget.isBangla
                            ? 'আপনার একটি পরিষ্কার ছবি দিন'
                            : 'Add a clear profile photo',
                      ),
                      Center(
                        child: GestureDetector(
                          onTap: pickProfileImage,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lightMaroon,
                              border: Border.all(color: primaryGold, width: 4),
                            ),
                            child: ClipOval(
                              child: profileImage != null
                                  ? (kIsWeb
                                      ? AppNetworkImage(profileImage!.path,
                                          fit: BoxFit.cover,
                                          width: 180,
                                          height: 180,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person,
                                                  size: 80,
                                                  color: primaryMaroon))
                                      : Image.file(profileImage!,
                                          fit: BoxFit.cover,
                                          width: 180,
                                          height: 180))
                                  : const Icon(Icons.person,
                                      size: 80, color: primaryMaroon),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: pickProfileImage,
                          icon: const Icon(Icons.camera_alt_outlined,
                              color: primaryMaroon),
                          label: Text(
                            profileImage != null
                                ? (widget.isBangla
                                    ? 'ছবি পরিবর্তন করুন'
                                    : 'Change Photo')
                                : (widget.isBangla
                                    ? 'ছবি নির্বাচন করুন'
                                    : 'Choose Photo'),
                            style: const TextStyle(
                                color: primaryMaroon,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const Divider(height: 40),
                      sectionHeader(
                        icon: Icons.photo_library_outlined,
                        title: widget.isBangla ? 'আরো ছবি' : 'More Photos',
                        subtitle: widget.isBangla
                            ? 'সর্বোচ্চ ৫টা ছবি যোগ করুন (${additionalImages.length}/5)'
                            : 'Add up to 5 more photos (${additionalImages.length}/5)',
                      ),
                      _buildAdditionalImagesList(),
                      const Divider(height: 40),
                      sectionHeader(
                        icon: Icons.person_outline,
                        title:
                            widget.isBangla ? 'আপনার তথ্য' : 'Your Information',
                      ),
                      infoRow('Name', widget.name, Icons.person_outline),
                      infoRow('Gender', widget.gender, Icons.wc_outlined),
                      infoRow('Religion', widget.religion,
                          Icons.auto_awesome_outlined),
                      infoRow('Age', widget.age, Icons.cake_outlined),
                      infoRow('District', widget.district,
                          Icons.location_on_outlined),
                      infoRow('Marital Status', widget.maritalStatus,
                          Icons.favorite_border),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 30),

              // 🟢 ডান কলাম (আবাউট মি ও পার্টনার প্রেফারেন্স)
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionHeader(
                        icon: Icons.edit_note_outlined,
                        title: widget.isBangla ? 'আমার সম্পর্কে' : 'About Me',
                        subtitle: widget.isBangla
                            ? 'নিজের সম্পর্কে সংক্ষেপে লিখুন'
                            : 'Tell something about yourself',
                      ),
                      TextFormField(
                        controller: aboutController,
                        maxLines: 8,
                        maxLength: 500,
                        decoration: fieldDecoration(
                          label: widget.isBangla ? 'আমার সম্পর্কে' : 'About Me',
                          icon: Icons.person_pin_outlined,
                          hint: widget.isBangla
                              ? 'আপনার ব্যক্তিত্ব, পছন্দ, লক্ষ্য ইত্যাদি লিখুন...'
                              : 'Write about your personality, interests and goals...',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty)
                            return 'Please write something about yourself';
                          if (value.trim().length < 20)
                            return 'Please write at least 20 characters';
                          return null;
                        },
                      ),
                      const Divider(height: 40),
                      sectionHeader(
                        icon: Icons.favorite_outline,
                        title: widget.isBangla
                            ? 'জীবনসঙ্গীর পছন্দ'
                            : 'Partner Preference',
                        subtitle: widget.isBangla
                            ? 'আপনার পছন্দের জীবনসঙ্গী সম্পর্কে জানান'
                            : 'Tell us what you prefer in a partner',
                      ),
                      buildDropdown<String>(
                        label:
                            widget.isBangla ? 'পছন্দের বয়স' : 'Preferred Age',
                        icon: Icons.cake_outlined,
                        value: preferredAge,
                        items: preferredAgeOptions,
                        onChanged: (value) =>
                            setState(() => preferredAge = value),
                      ),
                      const SizedBox(height: 16),
                      buildDropdown<String>(
                        label: widget.isBangla
                            ? 'পছন্দের ধর্ম'
                            : 'Preferred Religion',
                        icon: Icons.auto_awesome_outlined,
                        value: preferredReligion,
                        items: religionOptions,
                        onChanged: (value) =>
                            setState(() => preferredReligion = value),
                      ),
                      const SizedBox(height: 16),
                      buildDropdown<String>(
                        label: widget.isBangla
                            ? 'পছন্দের শিক্ষাগত যোগ্যতা'
                            : 'Preferred Education',
                        icon: Icons.school_outlined,
                        value: preferredEducation,
                        items: educationOptions,
                        onChanged: (value) =>
                            setState(() => preferredEducation = value),
                      ),
                      const SizedBox(height: 16),
                      buildDropdown<String>(
                        label: widget.isBangla
                            ? 'পছন্দের পেশা'
                            : 'Preferred Profession',
                        icon: Icons.work_outline,
                        value: preferredProfession,
                        items: professionOptions,
                        onChanged: (value) =>
                            setState(() => preferredProfession = value),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: continueProfile,
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
                              Text(
                                widget.isBangla
                                    ? 'প্রোফাইল Preview দেখুন'
                                    : 'Preview Profile',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
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
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADDITIONAL IMAGES LIST (Shared Widget)
  // ============================================================
  Widget _buildAdditionalImagesList() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (additionalImages.length < 5)
            GestureDetector(
              onTap: pickAdditionalImage,
              child: Container(
                width: 100,
                height: 110,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: lightMaroon,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: primaryMaroon.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: primaryMaroon, size: 32),
                    const SizedBox(height: 6),
                    Text(
                      widget.isBangla ? 'যোগ করুন' : 'Add',
                      style: const TextStyle(
                          color: primaryMaroon,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ...additionalImages.asMap().entries.map((entry) {
            final index = entry.key;
            final image = entry.value;

            return Container(
              width: 100,
              height: 110,
              margin: const EdgeInsets.only(right: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: kIsWeb
                        ? AppNetworkImage(image.path,
                            width: 100,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: lightMaroon,
                                child: const Icon(Icons.person,
                                    color: primaryMaroon)))
                        : Image.file(image,
                            width: 100, height: 110, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => removeAdditionalImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
