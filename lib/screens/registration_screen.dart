import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/colors.dart';
import '../services/referral_service.dart';
import 'verify_email_screen.dart';

// ============================================================
// REGISTRATION SCREEN
// ============================================================

class RegistrationScreen extends StatefulWidget {
  final bool isBangla;

  const RegistrationScreen({super.key, required this.isBangla});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final referralController = TextEditingController();

  String? gender;
  String? religion;

  bool isCreatingAccount = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    referralController.dispose();
    super.dispose();
  }

  // ============================================================
  // CREATE ACCOUNT
  // 1. Firebase Auth user create
  // 2. Firestore-এ basic info save (email verify-এর আগেই)
  // 3. Verification email send
  // 4. Referral apply
  // 5. VerifyEmailScreen-এ navigate
  // ============================================================

  Future<void> createAccount() async {
    if (!formKey.currentState!.validate()) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => isCreatingAccount = true);

    try {
      // ----------------------------------------------------------
      // 1. Create Firebase Auth user
      // ----------------------------------------------------------
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('User account could not be created.');
      }

      // ----------------------------------------------------------
      // 2. Firestore-এ basic info immediate save
      //    (email verify-এর আগেই — interruption-এও data হারাবে না)
      // ----------------------------------------------------------
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': nameController.text.trim(),
          'gender': gender ?? '',
          'religion': religion ?? '',
          'email': email,
          'phone': phoneController.text.trim(),
          'profileCompleted': false, // ← profile setup-এ true হবে
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('✅ [Registration] Basic info saved to Firestore');
      } catch (e) {
        debugPrint('⚠️ [Registration] Firestore save failed: $e');
        // Firestore write fail হলেও account থাকবে — user পরে edit থেকে save করতে পারবে
        // কঠোর policy চাইলে: await user.delete(); throw;
      }

      // ----------------------------------------------------------
      // 3. Verification email send
      // ----------------------------------------------------------
      await user.sendEmailVerification();

      // ----------------------------------------------------------
      // 4. Referral apply (if provided)
      // ----------------------------------------------------------
      if (referralController.text.trim().isNotEmpty) {
        await ReferralService.applyReferralCode(
          newUserUid: user.uid,
          code: referralController.text.trim(),
        );
      }

      if (!mounted) return;

      // ----------------------------------------------------------
      // 5. Verify Email screen-এ যাই
      // ----------------------------------------------------------
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            isBangla: widget.isBangla,
            name: nameController.text.trim(),
            gender: gender!,
            religion: religion!,
            email: email,
            phone: phoneController.text.trim(),
          ),
        ),
      );
    }
    // ==========================================================
    // FIREBASE AUTH ERRORS
    // ==========================================================
    on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = widget.isBangla
              ? 'এই ইমেইল দিয়ে ইতিমধ্যে একটি অ্যাকাউন্ট আছে।'
              : 'An account already exists with this email.';
          break;

        case 'invalid-email':
          message = widget.isBangla
              ? 'ইমেইল ঠিকানাটি সঠিক নয়।'
              : 'The email address is not valid.';
          break;

        case 'weak-password':
          message = widget.isBangla
              ? 'পাসওয়ার্ডটি খুব দুর্বল। আরও শক্তিশালী পাসওয়ার্ড ব্যবহার করুন।'
              : 'The password is too weak. Please use a stronger password.';
          break;

        case 'operation-not-allowed':
          message = widget.isBangla
              ? 'Email/Password login Firebase-এ এখনো সক্রিয় করা হয়নি।'
              : 'Email/Password authentication is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message = widget.isBangla
              ? 'ইন্টারনেট সংযোগ পরীক্ষা করুন।'
              : 'Please check your internet connection.';
          break;

        default:
          message = widget.isBangla
              ? 'অ্যাকাউন্ট তৈরি করা যায়নি। আবার চেষ্টা করুন।'
              : 'Could not create the account. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isBangla
                ? 'একটি সমস্যা হয়েছে। আবার চেষ্টা করুন।'
                : 'Something went wrong. Please try again.',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isCreatingAccount = false);
      }
    }
  }

  // ============================================================
  // INPUT DECORATION
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
        title: Text(
          bn ? 'আপনার যাত্রা শুরু করুন' : 'Begin Your Journey',
          style: const TextStyle(fontWeight: FontWeight.bold, color: mainText),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INTRO CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFBF5E8), Color(0xFFF7EBEE)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bn
                          ? 'চলুন, আপনাকে একটু জানি 💕'
                          : 'Let\'s get to know you 💕',
                      style: TextStyle(
                        fontSize: bn ? 23 : 24,
                        fontWeight: FontWeight.w800,
                        color: mainText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      bn
                          ? 'কিছু তথ্য আমাদের আপনাকে আরও ভালোভাবে বুঝতে সাহায্য করবে।'
                          : 'A few details will help us create a meaningful experience for you.',
                      style: const TextStyle(color: secondaryText, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Text(
                bn ? 'আপনার সম্পর্কে' : 'About You',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
              ),

              const SizedBox(height: 12),

              // NAME
              TextFormField(
                controller: nameController,
                decoration: fieldDecoration(
                  label: bn ? 'পূর্ণ নাম' : 'Full Name',
                  hint: bn ? 'আপনার নাম কী?' : 'What should we call you?',
                  icon: Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return bn ? 'আপনার নাম লিখুন' : 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // GENDER
              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: fieldDecoration(
                  label: bn ? 'লিঙ্গ' : 'Gender',
                  icon: Icons.person_2_outlined,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text(bn ? 'পুরুষ' : 'Male'),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text(bn ? 'নারী' : 'Female'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => gender = value);
                },
                validator: (value) {
                  if (value == null) {
                    return bn
                        ? 'লিঙ্গ নির্বাচন করুন'
                        : 'Please select your gender';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // RELIGION
              DropdownButtonFormField<String>(
                initialValue: religion,
                decoration: fieldDecoration(
                  label: bn ? 'ধর্ম' : 'Religion',
                  icon: Icons.auto_awesome_outlined,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Islam',
                    child: Text(bn ? 'ইসলাম' : 'Islam'),
                  ),
                  DropdownMenuItem(
                    value: 'Hinduism',
                    child: Text(bn ? 'হিন্দুধর্ম' : 'Hinduism'),
                  ),
                  DropdownMenuItem(
                    value: 'Christianity',
                    child: Text(bn ? 'খ্রিস্টধর্ম' : 'Christianity'),
                  ),
                  DropdownMenuItem(
                    value: 'Buddhism',
                    child: Text(bn ? 'বৌদ্ধধর্ম' : 'Buddhism'),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child: Text(bn ? 'অন্যান্য' : 'Other'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => religion = value);
                },
                validator: (value) {
                  if (value == null) {
                    return bn
                        ? 'ধর্ম নির্বাচন করুন'
                        : 'Please select your religion';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 25),

              Text(
                bn ? 'যোগাযোগ ও নিরাপত্তা' : 'Contact & Security',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
              ),

              const SizedBox(height: 12),

              // EMAIL
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: fieldDecoration(
                  label: bn ? 'ইমেইল' : 'Email',
                  hint: 'you@example.com',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return bn ? 'ইমেইল লিখুন' : 'Please enter your email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return bn
                        ? 'সঠিক ইমেইল লিখুন'
                        : 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // PHONE
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: fieldDecoration(
                  label: bn ? 'মোবাইল নম্বর' : 'Phone Number',
                  hint: '01XXXXXXXXX',
                  icon: Icons.phone_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return bn
                        ? 'মোবাইল নম্বর লিখুন'
                        : 'Please enter your phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // PASSWORD
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: fieldDecoration(
                  label: bn ? 'পাসওয়ার্ড' : 'Password',
                  hint: bn ? 'কমপক্ষে ৬ অক্ষর' : 'At least 6 characters',
                  icon: Icons.lock_outline,
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return bn
                        ? 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে'
                        : 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // REFERRAL CODE (Optional)
              // ==================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: lightGold,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryGold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.card_giftcard_rounded,
                          color: deepGold,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          bn
                              ? 'Referral Code (ঐচ্ছিক)'
                              : 'Referral Code (optional)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: mainText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bn
                          ? 'বন্ধুর কাছ থেকে পেলে এখানে দিন'
                          : 'Enter code if you have one from a friend',
                      style: const TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: referralController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: fieldDecoration(
                        label: bn ? 'Code' : 'Code',
                        icon: Icons.qr_code_2_outlined,
                        hint: 'ABC123',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // CREATE PROFILE BUTTON
              SizedBox(
                width: double.infinity,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC59B4B), Color(0xFF8B1E3F)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryMaroon.withValues(alpha: .22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isCreatingAccount ? null : createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isCreatingAccount
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
                              Text(
                                bn
                                    ? 'আমার প্রোফাইল তৈরি করুন'
                                    : 'Create My Profile',
                                style: TextStyle(
                                  fontSize: bn ? 16 : 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.favorite_rounded),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              Center(
                child: Text(
                  bn
                      ? 'পরের ধাপে ইমেইল verify করতে হবে।'
                      : 'Next step: verify your email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
