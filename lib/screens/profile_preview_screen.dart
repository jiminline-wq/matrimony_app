import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../theme/colors.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';

// ============================================================
// PROFILE PREVIEW SCREEN
// ============================================================

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
  final List<File> additionalImages;    // ← NEW

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
    required this.additionalImages,     // ← NEW
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

  // Cloudinary config
  static const String cloudinaryCloudName = 'acctuglm';
  static const String cloudinaryUploadPreset = 'jibon_sathi_profiles';

  // ============================================================
  // UPLOAD IMAGE TO CLOUDINARY
  // ============================================================

  Future<String> uploadImageToCloudinary(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..fields['folder'] = 'profile_images'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final responseString = String.fromCharCodes(responseData);
    final jsonMap = jsonDecode(responseString);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonMap['secure_url'] as String;
    } else {
      throw Exception(
        'Cloudinary upload failed: ${jsonMap['error']['message']}',
      );
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> saveProfileToFirestore() async {
    final bn = widget.isBangla;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn ? 'আপনি লগইন করা নেই।' : 'You are not logged in.',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // ========================================================
      // STEP 1: UPLOAD ALL PHOTOS TO CLOUDINARY
      // ========================================================

      String photoUrl = '';
      List<String> photoUrls = [];

      // 1a. Main photo
      if (widget.profileImage != null) {
        photoUrl = await uploadImageToCloudinary(widget.profileImage!);
        if (photoUrl.isNotEmpty) {
          photoUrls.add(photoUrl);
        }
      }

      // 1b. Additional photos
      for (final image in widget.additionalImages) {
        try {
          final url = await uploadImageToCloudinary(image);
          if (url.isNotEmpty) {
            photoUrls.add(url);
          }
        } catch (e) {
          // skip failed uploads
        }
      }

      // ========================================================
      // STEP 2: SAVE PROFILE TO FIRESTORE
      // ========================================================

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
        photoUrls: photoUrls,           // ← NEW
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
        MaterialPageRoute(
          builder: (_) => HomeScreen(isBangla: bn),
        ),
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
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget infoRow(
    String title,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lightMaroon,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 19,
              color: primaryMaroon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: mainText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  color: lightGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: deepGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: mainText,
                  ),
                ),
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    // সব photo-র লিস্ট
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
          style: const TextStyle(
            color: mainText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ==========================================
            // PROFILE HEADER (with photo carousel)
            // ==========================================
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
                  // Photo carousel
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
                                color: primaryGold,
                                width: 4,
                              ),
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
                          // Dot indicators
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
                                        color: primaryMaroon
                                            .withValues(alpha: 0.3),
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
                        border: Border.all(
                          color: primaryGold,
                          width: 4,
                        ),
                      ),
                      child: const ClipOval(
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: primaryMaroon,
                        ),
                      ),
                    ),

                  const SizedBox(height: 15),

                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: mainText,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${widget.age} • ${widget.district}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: secondaryText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.maritalStatus,
                      style: const TextStyle(
                        color: primaryMaroon,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // BASIC INFORMATION
            // ==========================================
            sectionCard(
              title: bn ? "মৌলিক তথ্য" : "Basic Information",
              icon: Icons.person_outline,
              children: [
                infoRow(bn ? "লিঙ্গ" : "Gender", widget.gender, Icons.wc),
                infoRow(bn ? "ধর্ম" : "Religion", widget.religion,
                    Icons.auto_awesome_outlined),
                infoRow(bn ? "জেলা" : "District", widget.district,
                    Icons.location_on_outlined),
                infoRow(bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                    widget.maritalStatus, Icons.favorite_outline),
                infoRow(bn ? "উচ্চতা" : "Height", widget.height,
                    Icons.height),
                infoRow(bn ? "গায়ের রং" : "Skin Tone", widget.skinTone,
                    Icons.color_lens_outlined),
              ],
            ),

            // ==========================================
            // EDUCATION & CAREER
            // ==========================================
            sectionCard(
              title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
              icon: Icons.school_outlined,
              children: [
                infoRow(bn ? "শিক্ষাগত যোগ্যতা" : "Education",
                    widget.education, Icons.school_outlined),
                infoRow(bn ? "পেশা" : "Profession", widget.profession,
                    Icons.work_outline),
              ],
            ),

            // ==========================================
            // ABOUT ME
            // ==========================================
            sectionCard(
              title: bn ? "নিজের সম্পর্কে" : "About Me",
              icon: Icons.favorite_outline,
              children: [
                Text(
                  widget.aboutMe,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: mainText,
                  ),
                ),
              ],
            ),

            // ==========================================
            // PARTNER PREFERENCE
            // ==========================================
            sectionCard(
              title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
              icon: Icons.favorite,
              children: [
                infoRow(bn ? "পছন্দের বয়স" : "Preferred Age",
                    widget.preferredAge, Icons.cake_outlined),
                infoRow(bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                    widget.preferredReligion, Icons.auto_awesome_outlined),
                infoRow(bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                    widget.preferredEducation, Icons.school_outlined),
                infoRow(bn ? "পছন্দের পেশা" : "Preferred Profession",
                    widget.preferredProfession, Icons.work_outline),
              ],
            ),

            const SizedBox(height: 5),

            // ==========================================
            // CONFIRM MESSAGE
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lightGold,
                borderRadius: BorderRadius.circular(15),
              ),
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
                        fontSize: 13,
                        height: 1.5,
                        color: mainText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ==========================================
            // CREATE PROFILE BUTTON
            // ==========================================
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryGold, primaryMaroon],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryMaroon.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        bn
                            ? "আমার প্রোফাইল তৈরি করুন"
                            : "Create My Profile",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              bn
                  ? "আপনি পরবর্তীতে আপনার প্রোফাইলের তথ্য পরিবর্তন করতে পারবেন।"
                  : "You can edit your profile information later.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}