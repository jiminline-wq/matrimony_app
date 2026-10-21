import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';

class ProfilePreviewScreen extends StatefulWidget {
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

  final File? profileImage;
  final List<File> additionalImages;

  final String aboutMe;
  final String preferredAge;
  final String preferredReligion;
  final String preferredEducation;
  final String preferredProfession;
  final String about;

  const ProfilePreviewScreen({
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
    required this.profileImage,
    required this.additionalImages,
    required this.aboutMe,
    required this.preferredAge,
    required this.preferredReligion,
    required this.preferredEducation,
    required this.preferredProfession,
    required this.about,
  });

  @override
  State<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends State<ProfilePreviewScreen> {
  bool isSaving = false;
  int _currentPhotoIndex = 0;

  static const String cloudinaryCloudName = 'acctuglm';
  static const String cloudinaryUploadPreset = 'jibon_sathi_profiles';

  // ============================================================
  // IMAGE UPLOAD LOGIC
  // ============================================================
  Future<String> uploadImageToCloudinary(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..fields['folder'] = 'profile_images'
      ..files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final responseString = String.fromCharCodes(responseData);
    final jsonMap = jsonDecode(responseString);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonMap['secure_url'] as String;
    } else {
      throw Exception(
          'Cloudinary upload failed: ${jsonMap['error']['message']}');
    }
  }

  Future<void> saveProfileToFirestore() async {
    final bn = widget.isBangla;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bn ? 'আপনি লগইন করা নেই।' : 'You are not logged in.'),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      String photoUrl = '';
      List<String> photoUrls = [];

      // ⚠️ ওয়েবে File আপলোড কাজ করে না, তাই চেক দেওয়া হলো
      if (!kIsWeb) {
        if (widget.profileImage != null) {
          photoUrl = await uploadImageToCloudinary(widget.profileImage!);
          if (photoUrl.isNotEmpty) photoUrls.add(photoUrl);
        }

        for (final image in widget.additionalImages) {
          try {
            final url = await uploadImageToCloudinary(image);
            if (url.isNotEmpty) photoUrls.add(url);
          } catch (e) {
            debugPrint("Image upload failed: $e");
          }
        }
      }

      final profile = UserProfile(
        uid: user.uid,
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
        aboutMe: widget.aboutMe,
        preferredAge: widget.preferredAge,
        preferredReligion: widget.preferredReligion,
        preferredEducation: widget.preferredEducation,
        preferredProfession: widget.preferredProfession,
        photoUrl: photoUrl,
        photoUrls: photoUrls,
        height: widget.height,
        skinTone: widget.skinTone,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profile.toMap(), SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn
                ? 'আপনার প্রোফাইল সফলভাবে তৈরি হয়েছে ❤️'
                : 'Your profile has been created successfully ❤️',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(isBangla: bn)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn
                ? 'প্রোফাইল সেভ করা যায়নি। আবার চেষ্টা করুন।'
                : 'Could not save profile. Please try again.',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 🌐 স্ক্রিন যদি ৮০০ পিক্সেলের বড় হয় (তাহলে ওয়েব লেআউট দেখাবে)
        if (constraints.maxWidth > 800) {
          return _buildWebLayout(bn);
        }
        // 📱 মোবাইলের জন্য অরিজিনাল লেআউট (কোনো পরিবর্তন নেই)
        return _buildMobileLayout(bn);
      },
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (আপনার অরিজিনাল ডিজাইন)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    final List<File> allPhotos = [
      if (widget.profileImage != null) widget.profileImage!,
      ...widget.additionalImages,
    ];

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: mainText),
        title: Text(
          bn ? "প্রোফাইল দেখুন" : "Review Your Profile",
          style: const TextStyle(color: mainText, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // PROFILE HEADER
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [lightMaroon, lightGold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        if (allPhotos.isNotEmpty)
                          SizedBox(
                            height: 150,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                        color: primaryGold, width: 4),
                                  ),
                                  child: ClipOval(
                                    child: PageView.builder(
                                      itemCount: allPhotos.length,
                                      onPageChanged: (index) {
                                        setState(
                                            () => _currentPhotoIndex = index);
                                      },
                                      itemBuilder: (context, index) {
                                        return Image.file(
                                          allPhotos[index],
                                          width: 150,
                                          height: 150,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                if (allPhotos.length > 1)
                                  Positioned(
                                    bottom: 2,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        allPhotos.length,
                                        (index) => Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentPhotoIndex == index
                                                ? primaryMaroon
                                                : Colors.white
                                                    .withValues(alpha: 0.7),
                                            border: Border.all(
                                              color: primaryMaroon.withValues(
                                                  alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: primaryGold, width: 4),
                            ),
                            child: const ClipOval(
                              child: Icon(Icons.person,
                                  size: 70, color: primaryMaroon),
                            ),
                          ),
                        const SizedBox(height: 15),
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: mainText),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${widget.age} • ${widget.district}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, color: secondaryText),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.maritalStatus,
                            style: const TextStyle(
                                color: primaryMaroon,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // মৌলিক তথ্য
                  _buildMobileSectionCard(
                    title: bn ? "মৌলিক তথ্য" : "Basic Information",
                    icon: Icons.person_outline,
                    children: [
                      _buildMobileInfoRow(
                          bn ? "লিঙ্গ" : "Gender", widget.gender, Icons.wc),
                      _buildMobileInfoRow(bn ? "ধর্ম" : "Religion",
                          widget.religion, Icons.auto_awesome_outlined),
                      _buildMobileInfoRow(bn ? "জেলা" : "District",
                          widget.district, Icons.location_on_outlined),
                      _buildMobileInfoRow(
                          bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                          widget.maritalStatus,
                          Icons.favorite_outline),
                      _buildMobileInfoRow(bn ? "উচ্চতা" : "Height",
                          widget.height, Icons.height),
                      _buildMobileInfoRow(bn ? "গায়ের রং" : "Skin Tone",
                          widget.skinTone, Icons.color_lens_outlined),
                    ],
                  ),
                  // শিক্ষা ও পেশা
                  _buildMobileSectionCard(
                    title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
                    icon: Icons.school_outlined,
                    children: [
                      _buildMobileInfoRow(bn ? "শিক্ষাগত যোগ্যতা" : "Education",
                          widget.education, Icons.school_outlined),
                      _buildMobileInfoRow(bn ? "পেশা" : "Profession",
                          widget.profession, Icons.work_outline),
                    ],
                  ),
                  // নিজের সম্পর্কে
                  _buildMobileSectionCard(
                    title: bn ? "নিজের সম্পর্কে" : "About Me",
                    icon: Icons.favorite_outline,
                    children: [
                      Text(widget.aboutMe,
                          style: const TextStyle(
                              fontSize: 15, height: 1.6, color: mainText)),
                    ],
                  ),
                  // জীবনসঙ্গীর পছন্দ
                  _buildMobileSectionCard(
                    title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
                    icon: Icons.favorite,
                    children: [
                      _buildMobileInfoRow(bn ? "পছন্দের বয়স" : "Preferred Age",
                          widget.preferredAge, Icons.cake_outlined),
                      _buildMobileInfoRow(
                          bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                          widget.preferredReligion,
                          Icons.auto_awesome_outlined),
                      _buildMobileInfoRow(
                          bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                          widget.preferredEducation,
                          Icons.school_outlined),
                      _buildMobileInfoRow(
                          bn ? "পছন্দের পেশা" : "Preferred Profession",
                          widget.preferredProfession,
                          Icons.work_outline),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Confirm Message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: lightGold,
                        borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: deepGold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bn
                                ? "আপনার তথ্যগুলো ভালোভাবে যাচাই করুন। পরবর্তীতে আপনি প্রোফাইলটি সম্পাদনা করতে পারবেন।"
                                : "Please review your information carefully. You will be able to edit your profile later.",
                            style: const TextStyle(
                                fontSize: 13, height: 1.5, color: mainText),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Create Profile Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [primaryGold, primaryMaroon]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: primaryMaroon.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: isSaving ? null : saveProfileToFirestore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 58),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)),
                            )
                          : Text(
                              bn
                                  ? "আমার প্রোফাইল তৈরি করুন"
                                  : "Create My Profile",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bn
                        ? "আপনি পরবর্তীতে আপনার প্রোফাইলের তথ্য পরিবর্তন করতে পারবেন।"
                        : "You can edit your profile information later.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
            ),
          ),
          // Mobile Ad
          if (!kIsWeb)
            const SafeArea(
              top: false,
              child: BannerAdWidget(placementId: AdConfig.placementProfileView),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 🌐 ২. ওয়েব লেআউট (আপনার দেওয়া স্ক্রিনশটের মতো)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    final List<File> allPhotos = [
      if (widget.profileImage != null) widget.profileImage!,
      ...widget.additionalImages,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // হালকা গ্রে ব্যাকগ্রাউন্ড
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: mainText),
        title: Text(
          bn ? "প্রোফাইল" : "Profile",
          style: const TextStyle(
              color: mainText, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.favorite_border, color: primaryMaroon),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.bookmark_border, color: primaryMaroon),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.more_vert, color: mainText),
              onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 900), // ম্যাক্স উইডথ
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // কভার ফটো ও টেক্সট
                        Container(
                          height: 450,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.grey.shade300,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (allPhotos.isNotEmpty && !kIsWeb)
                                  Image.file(allPhotos[0], fit: BoxFit.cover)
                                else if (kIsWeb)
                                  Container(
                                    color: Colors.grey.shade400,
                                    child: const Center(
                                        child: Text(
                                            "Image not available on web",
                                            style: TextStyle(
                                                color: Colors.white))),
                                  )
                                else
                                  const Icon(Icons.person,
                                      size: 100, color: Colors.white),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.center,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.8),
                                        Colors.transparent
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  right: 20,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.name,
                                            style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  color: Colors.white70,
                                                  size: 16),
                                              const SizedBox(width: 4),
                                              Text(widget.district,
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 16)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              widget.maritalStatus,
                                              style: const TextStyle(
                                                  color: primaryMaroon,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                          widget.age,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        // মৌলিক তথ্য কার্ড
                        _buildWebSectionCard(
                          title: bn ? "মৌলিক তথ্য" : "Basic Information",
                          icon: Icons.person_outline,
                          children: [
                            _buildWebInfoRow(
                                bn ? "লিঙ্গ" : "Gender",
                                widget.gender,
                                Icons.wc,
                                primaryMaroon,
                                lightMaroon),
                            _buildWebInfoRow(
                                bn ? "ধর্ম" : "Religion",
                                widget.religion,
                                Icons.auto_awesome_outlined,
                                Colors.orange,
                                Colors.orange.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "জেলা" : "District",
                                widget.district,
                                Icons.location_on_outlined,
                                Colors.blue,
                                Colors.blue.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                                widget.maritalStatus,
                                Icons.favorite_outline,
                                Colors.pink,
                                Colors.pink.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "উচ্চতা" : "Height",
                                widget.height,
                                Icons.height,
                                Colors.green,
                                Colors.green.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "গায়ের রং" : "Skin Tone",
                                widget.skinTone,
                                Icons.color_lens_outlined,
                                Colors.brown,
                                Colors.brown.withValues(alpha: 0.1)),
                          ],
                        ),
                        // শিক্ষা ও পেশা
                        _buildWebSectionCard(
                          title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
                          icon: Icons.school_outlined,
                          children: [
                            _buildWebInfoRow(
                                bn ? "শিক্ষাগত যোগ্যতা" : "Education",
                                widget.education,
                                Icons.school_outlined,
                                Colors.indigo,
                                Colors.indigo.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "পেশা" : "Profession",
                                widget.profession,
                                Icons.work_outline,
                                Colors.teal,
                                Colors.teal.withValues(alpha: 0.1)),
                          ],
                        ),
                        // নিজের সম্পর্কে
                        _buildWebSectionCard(
                          title: bn ? "নিজের সম্পর্কে" : "About Me",
                          icon: Icons.favorite_outline,
                          children: [
                            Text(widget.aboutMe,
                                style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: mainText)),
                          ],
                        ),
                        // জীবনসঙ্গীর পছন্দ
                        _buildWebSectionCard(
                          title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
                          icon: Icons.favorite,
                          children: [
                            _buildWebInfoRow(
                                bn ? "পছন্দের বয়স" : "Preferred Age",
                                widget.preferredAge,
                                Icons.cake_outlined,
                                Colors.deepPurple,
                                Colors.deepPurple.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                                widget.preferredReligion,
                                Icons.auto_awesome_outlined,
                                Colors.orange,
                                Colors.orange.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                                widget.preferredEducation,
                                Icons.school_outlined,
                                Colors.indigo,
                                Colors.indigo.withValues(alpha: 0.1)),
                            _buildWebInfoRow(
                                bn ? "পছন্দের পেশা" : "Preferred Profession",
                                widget.preferredProfession,
                                Icons.work_outline,
                                Colors.teal,
                                Colors.teal.withValues(alpha: 0.1)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // সেভ বাটন
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [primaryGold, primaryMaroon]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: primaryMaroon.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isSaving ? null : saveProfileToFirestore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white)))
                                : Text(
                                    bn
                                        ? "আমার প্রোফাইল তৈরি করুন"
                                        : "Create My Profile",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!kIsWeb)
            const SafeArea(
              top: false,
              child: BannerAdWidget(placementId: AdConfig.placementProfileView),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // মোবাইল উইজেট হেল্পার
  // ============================================================
  Widget _buildMobileInfoRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: lightMaroon, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: primaryMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 12, color: secondaryText)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: mainText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: lightGold, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: deepGold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: mainText)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // ওয়েব উইজেট হেল্পার
  // ============================================================
  Widget _buildWebInfoRow(String title, String value, IconData icon,
      Color iconColor, Color iconBg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 13, color: secondaryText)),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: mainText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSectionCard(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: lightGold, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: deepGold, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mainText)),
            ],
          ),
          const Divider(height: 30, thickness: 1),
          ...children,
        ],
      ),
    );
  }
}
