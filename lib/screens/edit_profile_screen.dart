import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../theme/colors.dart';
import '../models/user_profile.dart';

// ============================================================
// EDIT PROFILE SCREEN
// ============================================================

class EditProfileScreen extends StatefulWidget {
  final bool isBangla;
  final UserProfile profile;

  const EditProfileScreen({
    super.key,
    required this.isBangla,
    required this.profile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final formKey = GlobalKey<FormState>();

  // ============================================================
  // CONTROLLERS
  // ============================================================

  late TextEditingController nameController;
  late TextEditingController ageController;
  late TextEditingController phoneController;
  late TextEditingController aboutMeController;
  late TextEditingController educationController;
  late TextEditingController professionController;

  // ============================================================
  // DROPDOWN VALUES
  // ============================================================

  String? gender;
  String? religion;
  String? district;
  String? maritalStatus;
  String? preferredAge;
  String? height;
  String? skinTone;
  String? preferredReligion;
  String? preferredEducation;
  String? preferredProfession;

  bool isSaving = false;

  // ============================================================
  // PHOTO GALLERY STATE
  // ============================================================

  File? newProfileImage;                // নতুন main photo (ঐচ্ছিক)
  List<File> newAdditionalImages = [];  // নতুন additional photos
  List<String> existingPhotoUrls = [];  // Firestore থেকে আসা photos

  final ImagePicker imagePicker = ImagePicker();

  // Cloudinary config
  static const String cloudinaryCloudName = 'acctuglm';
  static const String cloudinaryUploadPreset = 'jibon_sathi_profiles';

  // ============================================================
  // DATA OPTIONS
  // ============================================================

  final List<String> genderOptions = ['Male', 'Female'];

  final List<String> religionOptions = [
    'Islam',
    'Hinduism',
    'Christianity',
    'Buddhism',
    'Other',
  ];

  final List<String> districts = [
    'Bagerhat', 'Bandarban', 'Barguna', 'Barishal', 'Bhola', 'Bogura',
    'Brahmanbaria', 'Chandpur', 'Chattogram', 'Chuadanga', "Cox's Bazar",
    'Cumilla', 'Dhaka', 'Dinajpur', 'Faridpur', 'Feni', 'Gaibandha',
    'Gazipur', 'Gopalganj', 'Habiganj', 'Jamalpur', 'Jashore',
    'Jhalokathi', 'Jhenaidah', 'Joypurhat', 'Khagrachhari', 'Khulna',
    'Kishoreganj', 'Kurigram', 'Kushtia', 'Lakshmipur', 'Lalmonirhat',
    'Madaripur', 'Magura', 'Manikganj', 'Meherpur', 'Moulvibazar',
    'Munshiganj', 'Mymensingh', 'Naogaon', 'Narail', 'Narayanganj',
    'Narsingdi', 'Natore', 'Netrokona', 'Nilphamari', 'Noakhali',
    'Pabna', 'Panchagarh', 'Patuakhali', 'Pirojpur', 'Rajbari',
    'Rajshahi', 'Rangamati', 'Rangpur', 'Satkhira', 'Shariatpur',
    'Sherpur', 'Sirajganj', 'Sunamganj', 'Sylhet', 'Tangail',
    'Thakurgaon',
  ];

  final List<String> maritalStatuses = [
    'Never Married',
    'Divorced',
    'Widowed',
    'Separated',
  ];

  final List<String> preferredAgeOptions = [
    '18 - 22', '23 - 27', '28 - 32', '33 - 37', '38 - 42', '43 - 50',
    'Any Age',
  ];

  final List<String> preferredReligionOptions = [
    'Islam', 'Hinduism', 'Christianity', 'Buddhism', 'Other',
    'Any Religion',
  ];

  final List<String> preferredEducationOptions = [
    'SSC', 'HSC', 'Diploma', 'Bachelor', 'BSc', 'BSc in Engineering',
    'BA', 'BBA', 'BSS', 'BCom', 'LLB', 'MBBS', 'BDS', 'BPharm',
    'BSc Nursing', 'Master', 'MSc', 'MA', 'MBA', 'MSS', 'LLM',
    'MPharm', 'MPH', 'MPhil', 'PhD', 'Any Education',
  ];

  final List<String> preferredProfessionOptions = [
    'Government Job', 'Private Job', 'Teacher', 'Engineer', 'Doctor',
    'Banker', 'Lawyer', 'Freelancer', 'Business', 'Student',
    'House Maker', 'Other', 'Any Profession',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final p = widget.profile;

    nameController = TextEditingController(text: p.name);
    ageController = TextEditingController(text: p.age);
    phoneController = TextEditingController(text: p.phone);
    aboutMeController = TextEditingController(text: p.aboutMe);
    educationController = TextEditingController(text: p.education);
    professionController = TextEditingController(text: p.profession);

    gender = p.gender.isNotEmpty ? p.gender : null;
    religion = p.religion.isNotEmpty ? p.religion : null;
    district = p.district.isNotEmpty ? p.district : null;
    maritalStatus = p.maritalStatus.isNotEmpty ? p.maritalStatus : null;
    height = p.height.isNotEmpty ? p.height : null;
    skinTone = p.skinTone.isNotEmpty ? p.skinTone : null;
    preferredAge = p.preferredAge.isNotEmpty ? p.preferredAge : null;
    preferredReligion =
        p.preferredReligion.isNotEmpty ? p.preferredReligion : null;
    preferredEducation =
        p.preferredEducation.isNotEmpty ? p.preferredEducation : null;
    preferredProfession =
        p.preferredProfession.isNotEmpty ? p.preferredProfession : null;

    // Existing photos লোড
    existingPhotoUrls = List<String>.from(p.photoUrls);
    if (existingPhotoUrls.isEmpty && p.photoUrl.isNotEmpty) {
      existingPhotoUrls = [p.photoUrl];
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    aboutMeController.dispose();
    educationController.dispose();
    professionController.dispose();
    super.dispose();
  }

  // ============================================================
  // PHOTO PICKERS
  // ============================================================

  Future<void> pickMainPhoto() async {
    final XFile? picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (picked == null) return;

    setState(() {
      newProfileImage = File(picked.path);
    });
  }

  Future<void> pickAdditionalPhoto() async {
    final totalPhotos =
        existingPhotoUrls.length + newAdditionalImages.length;

    if (totalPhotos >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isBangla
                ? 'সর্বোচ্চ ৬টা ছবি থাকতে পারে।'
                : 'Maximum 6 photos allowed.',
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
      newAdditionalImages.add(File(picked.path));
    });
  }

  void removeExistingPhoto(int index) {
    setState(() {
      existingPhotoUrls.removeAt(index);
    });
  }

  void removeNewAdditionalPhoto(int index) {
    setState(() {
      newAdditionalImages.removeAt(index);
    });
  }

  // ============================================================
  // UPLOAD TO CLOUDINARY
  // ============================================================

  Future<String> uploadToCloudinary(File imageFile) async {
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
      throw Exception('Upload failed');
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> saveProfile() async {
    final bn = widget.isBangla;

    if (!formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // ========================================================
      // STEP 1: Upload new main photo (if changed)
      // ========================================================
      String mainPhotoUrl = widget.profile.photoUrl;

      if (newProfileImage != null) {
        mainPhotoUrl = await uploadToCloudinary(newProfileImage!);
      }

      // ========================================================
      // STEP 2: Upload new additional photos
      // ========================================================
      final List<String> uploadedNewPhotos = [];
      for (final image in newAdditionalImages) {
        try {
          final url = await uploadToCloudinary(image);
          uploadedNewPhotos.add(url);
        } catch (e) {
          // Skip failed uploads
        }
      }

      // ========================================================
      // STEP 3: Combine photo URLs
      // ========================================================
      final List<String> finalPhotoUrls = [
        if (mainPhotoUrl.isNotEmpty) mainPhotoUrl,
        ...existingPhotoUrls.where((url) => url != mainPhotoUrl),
        ...uploadedNewPhotos,
      ];

      // ========================================================
      // STEP 4: Update Firestore
      // ========================================================
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': nameController.text.trim(),
        'gender': gender ?? '',
        'religion': religion ?? '',
        'phone': phoneController.text.trim(),
        'age': ageController.text.trim(),
        'district': district ?? '',
        'maritalStatus': maritalStatus ?? '',
        'education': educationController.text.trim(),
        'profession': professionController.text.trim(),
        'aboutMe': aboutMeController.text.trim(),
        'preferredAge': preferredAge ?? '',
        'preferredReligion': preferredReligion ?? '',
        'preferredEducation': preferredEducation ?? '',
        'preferredProfession': preferredProfession ?? '',
        'height': height ?? '',
        'skinTone': skinTone ?? '',
        'photoUrl': mainPhotoUrl,
        'photoUrls': finalPhotoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn
                ? 'প্রোফাইল সফলভাবে আপডেট হয়েছে ❤️'
                : 'Profile updated successfully ❤️',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bn
                ? 'প্রোফাইল আপডেট করা যায়নি। আবার চেষ্টা করুন।'
                : 'Could not update profile. Please try again.',
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
  // DROPDOWN
  // ============================================================

  Widget buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: fieldDecoration(label: label, icon: icon),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget sectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightMaroon,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryMaroon, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: mainText,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PHOTO GALLERY SECTION
  // ============================================================

  Widget _buildPhotoGallery(bool bn) {
    final totalPhotos = existingPhotoUrls.length + newAdditionalImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lightMaroon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: primaryMaroon,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bn ? 'ছবি গ্যালারি' : 'Photo Gallery',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lightMaroon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalPhotos/6',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryMaroon,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal photo list
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Main photo box
              GestureDetector(
                onTap: pickMainPhoto,
                child: Container(
                  width: 110,
                  height: 130,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: lightMaroon,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryGold,
                      width: 2,
                    ),
                  ),
                  child: newProfileImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                newProfileImage!,
                                width: 110,
                                height: 130,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryMaroon,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Main',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: primaryMaroon,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bn ? 'মেইন\nছবি' : 'Main\nPhoto',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: primaryMaroon,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Existing photos
              ...existingPhotoUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final url = entry.value;

                return Container(
                  width: 110,
                  height: 130,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          url,
                          width: 110,
                          height: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: lightMaroon,
                            child: const Icon(
                              Icons.broken_image,
                              color: primaryMaroon,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => removeExistingPhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // New additional photos
              ...newAdditionalImages.asMap().entries.map((entry) {
                final index = entry.key;
                final image = entry.value;

                return Container(
                  width: 110,
                  height: 130,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          image,
                          width: 110,
                          height: 130,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => removeNewAdditionalPhoto(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Add more button
              if (totalPhotos < 6)
                GestureDetector(
                  onTap: pickAdditionalPhoto,
                  child: Container(
                    width: 110,
                    height: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: primaryMaroon.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: primaryMaroon,
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bn ? 'আরো যোগ করুন' : 'Add More',
                          style: const TextStyle(
                            color: primaryMaroon,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Hint text
        Text(
          bn
              ? 'Main photo ছাড়াও সর্বোচ্চ ৫টা ছবি যোগ করতে পারবেন'
              : 'Add up to 5 more photos besides main photo',
          style: const TextStyle(
            fontSize: 11,
            color: secondaryText,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
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
          bn ? 'প্রোফাইল এডিট' : 'Edit Profile',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
        actions: [
          IconButton(
            onPressed: isSaving ? null : saveProfile,
            icon: const Icon(Icons.check, color: primaryMaroon),
            tooltip: bn ? 'সেভ করুন' : 'Save',
          ),
        ],
      ),

      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [

              // ==================================================
              // PHOTO GALLERY (NEW)
              // ==================================================

              _buildPhotoGallery(bn),

              const SizedBox(height: 10),

              // ==================================================
              // BASIC INFORMATION
              // ==================================================

              sectionHeader(
                icon: Icons.person_outline,
                title: bn ? 'মৌলিক তথ্য' : 'Basic Information',
              ),

              TextFormField(
                controller: nameController,
                decoration: fieldDecoration(
                  label: bn ? 'পূর্ণ নাম' : 'Full Name',
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return bn ? 'নাম লিখুন' : 'Enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'লিঙ্গ' : 'Gender',
                icon: Icons.wc_outlined,
                value: gender,
                items: genderOptions,
                onChanged: (value) {
                  setState(() => gender = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'ধর্ম' : 'Religion',
                icon: Icons.auto_awesome_outlined,
                value: religion,
                items: religionOptions,
                onChanged: (value) {
                  setState(() => religion = value);
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration(
                  label: bn ? 'বয়স' : 'Age',
                  icon: Icons.cake_outlined,
                  hint: 'e.g. 28',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final age = int.tryParse(value.trim());
                  if (age == null || age < 18 || age > 100) {
                    return bn ? 'বয়স ১৮-১০০ দিন' : 'Age 18-100';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'জেলা' : 'District',
                icon: Icons.location_on_outlined,
                value: district,
                items: districts,
                onChanged: (value) {
                  setState(() => district = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'বৈবাহিক অবস্থা' : 'Marital Status',
                icon: Icons.favorite_border,
                value: maritalStatus,
                items: maritalStatuses,
                onChanged: (value) {
                  setState(() => maritalStatus = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'উচ্চতা' : 'Height',
                icon: Icons.height,
                value: height,
                items: const [
                  "4'6\"", "4'7\"", "4'8\"", "4'9\"", "4'10\"", "4'11\"",
                  "5'0\"", "5'1\"", "5'2\"", "5'3\"", "5'4\"", "5'5\"",
                  "5'6\"", "5'7\"", "5'8\"", "5'9\"", "5'10\"", "5'11\"",
                  "6'0\"", "6'1\"", "6'2\"", "6'3\"", "6'4\"", "6'5\"",
                  "6'6\"", "6'7\"", "6'8\"", "6'9\"", "6'10\"", "6'11\"",
                  "7'0\"",
                ],
                onChanged: (value) {
                  setState(() => height = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn ? 'গায়ের রং' : 'Skin Tone',
                icon: Icons.color_lens_outlined,
                value: skinTone,
                items: const [
                  'Very Fair (উজ্জ্বল ফর্সা)',
                  'Fair (ফর্সা)',
                  'Wheatish (উজ্জ্বল শ্যামলা)',
                  'Medium (শ্যামলা)',
                  'Dark (কালো)',
                ],
                onChanged: (value) {
                  setState(() => skinTone = value);
                },
              ),

              // ==================================================
              // CONTACT
              // ==================================================

              sectionHeader(
                icon: Icons.contact_mail_outlined,
                title: bn ? 'যোগাযোগ' : 'Contact',
              ),

              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: fieldDecoration(
                  label: bn ? 'মোবাইল নম্বর' : 'Phone Number',
                  icon: Icons.phone_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),

              // ==================================================
              // EDUCATION & PROFESSION
              // ==================================================

              sectionHeader(
                icon: Icons.school_outlined,
                title: bn ? 'শিক্ষা ও পেশা' : 'Education & Profession',
              ),

              TextFormField(
                controller: educationController,
                maxLines: 2,
                decoration: fieldDecoration(
                  label: bn ? 'শিক্ষাগত যোগ্যতা' : 'Education',
                  icon: Icons.school_outlined,
                  hint: bn
                      ? 'যেমন: BSc in CSE, DU'
                      : 'e.g. BSc in CSE, DU',
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: professionController,
                maxLines: 2,
                decoration: fieldDecoration(
                  label: bn ? 'পেশা' : 'Profession',
                  icon: Icons.work_outline,
                  hint: bn
                      ? 'যেমন: Software Engineer'
                      : 'e.g. Software Engineer',
                ),
              ),

              // ==================================================
              // ABOUT ME
              // ==================================================

              sectionHeader(
                icon: Icons.edit_note_outlined,
                title: bn ? 'আমার সম্পর্কে' : 'About Me',
              ),

              TextFormField(
                controller: aboutMeController,
                maxLines: 5,
                maxLength: 500,
                decoration: fieldDecoration(
                  label: bn ? 'আমার সম্পর্কে' : 'About Me',
                  icon: Icons.person_pin_outlined,
                  hint: bn
                      ? 'আপনার ব্যক্তিত্ব, পছন্দ, লক্ষ্য...'
                      : 'Your personality, interests, goals...',
                ),
              ),

              // ==================================================
              // PARTNER PREFERENCE
              // ==================================================

              sectionHeader(
                icon: Icons.favorite_outline,
                title: bn
                    ? 'জীবনসঙ্গীর পছন্দ'
                    : 'Partner Preference',
              ),

              buildDropdown(
                label: bn ? 'পছন্দের বয়স' : 'Preferred Age',
                icon: Icons.cake_outlined,
                value: preferredAge,
                items: preferredAgeOptions,
                onChanged: (value) {
                  setState(() => preferredAge = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn
                    ? 'পছন্দের ধর্ম'
                    : 'Preferred Religion',
                icon: Icons.auto_awesome_outlined,
                value: preferredReligion,
                items: preferredReligionOptions,
                onChanged: (value) {
                  setState(() => preferredReligion = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn
                    ? 'পছন্দের শিক্ষা'
                    : 'Preferred Education',
                icon: Icons.school_outlined,
                value: preferredEducation,
                items: preferredEducationOptions,
                onChanged: (value) {
                  setState(() => preferredEducation = value);
                },
              ),

              const SizedBox(height: 14),

              buildDropdown(
                label: bn
                    ? 'পছন্দের পেশা'
                    : 'Preferred Profession',
                icon: Icons.work_outline,
                value: preferredProfession,
                items: preferredProfessionOptions,
                onChanged: (value) {
                  setState(() => preferredProfession = value);
                },
              ),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              const SizedBox(height: 30),

              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined),
                            const SizedBox(width: 10),
                            Text(
                              bn ? 'সেভ করুন' : 'Save Changes',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
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
}