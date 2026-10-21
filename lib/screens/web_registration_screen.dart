import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';
import 'login_screen.dart';

class WebRegistrationScreen extends StatefulWidget {
  const WebRegistrationScreen({super.key});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isHoveringButton = false;

  @override
  void initState() {
    super.initState();
    // ব্যাকগ্রাউন্ড অ্যানিমেশনের জন্য
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return const Center(
              child: Text('অনুগ্রহ করে কম্পিউটার বা বড় স্ক্রিন থেকে ওপেন করুন'),
            );
          }
          return Row(
            children: [
              // 🟢 বাম দিকের অংশ (Branding & Animation)
              Expanded(
                flex: 6,
                child: _buildLeftHeroSection(),
              ),

              // ⚪ ডান দিকের অংশ (Registration Form)
              Expanded(
                flex: 5,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    child: _buildPremiumFormCard(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // 🟢 বাম দিকের হিরো সেকশন (অ্যানিমেশন ও ব্র্যান্ডিং)
  // ============================================================
  Widget _buildLeftHeroSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B1E3F), Color(0xFF5E1128)],
        ),
      ),
      child: Stack(
        children: [
          // ভাসমান হার্ট অ্যানিমেশন
          ...List.generate(5, (index) {
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final movement =
                    math.sin(_animationController.value * math.pi * 2 + index) *
                        20;
                return Positioned(
                  left: 50.0 + (index * 100),
                  top: 100.0 + (index * 80) + movement,
                  child: Opacity(
                    opacity: 0.05 + (index * 0.02),
                    child: const Icon(Icons.favorite,
                        size: 100, color: Colors.white),
                  ),
                );
              },
            );
          }),

          // মূল লেখা ও ব্র্যান্ডিং
          Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ট্রাস্ট ব্যাজ
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(30),
                    border:
                        Border.all(color: primaryGold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified, color: primaryGold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'বাংলাদেশের বিশ্বস্ত ম্যাট্রিমনি',
                        style: GoogleFonts.hindSiliguri(
                          color: primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                Text(
                  'আপনার জীবনসাথী\nখুঁজুন সহজে ও নিরাপদে',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'হাজারো ভেরিফাইড প্রোফাইল থেকে খুঁজে নিন আপনার পছন্দের মানুষ।\nআজই যুক্ত হোন আমাদের পরিবারে এবং শুরু করুন নতুন যাত্রা।',
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),

                // সোশ্যাল প্রুফ (Social Proof)
                Row(
                  children: [
                    _buildTrustIndicator(Icons.people_alt, '১০,০০০+ সদস্য'),
                    const SizedBox(width: 30),
                    _buildTrustIndicator(Icons.lock_person, '১০০% সুরক্ষিত'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustIndicator(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.greenAccent, size: 24),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.hindSiliguri(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ⚪ ডান দিকের গ্লাস ফর্ম কার্ড (Glassmorphism)
  // ============================================================
  Widget _buildPremiumFormCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 550),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ফ্রি রেজিস্ট্রেশন',
            style: GoogleFonts.hindSiliguri(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: deepMaroon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'আপনার তথ্য দিয়ে আজই অ্যাকাউন্ট তৈরি করুন।',
            style: GoogleFonts.hindSiliguri(fontSize: 16, color: secondaryText),
          ),
          const SizedBox(height: 32),

          // নাম এবং মোবাইল নম্বর পাশাপাশি
          Row(
            children: [
              Expanded(
                  child: _buildPremiumField(
                      'আপনার পুরো নাম', Icons.person_outline)),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      _buildPremiumField('মোবাইল নম্বর', Icons.phone_outlined)),
            ],
          ),
          const SizedBox(height: 20),

          // ইমেইল
          _buildPremiumField('ইমেইল অ্যাড্রেস', Icons.email_outlined),
          const SizedBox(height: 20),

          // পাসওয়ার্ড
          _buildPremiumField('পাসওয়ার্ড (কমপক্ষে ৬ অক্ষর)', Icons.lock_outline,
              isObscure: true),

          const SizedBox(height: 32),

          // প্রিমিয়াম হোভার বাটন
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringButton = true),
            onExit: (_) => setState(() => _isHoveringButton = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHoveringButton
                      ? [primaryMaroon, deepMaroon]
                      : [const Color(0xFFC59B4B), primaryMaroon],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryMaroon.withValues(
                        alpha: _isHoveringButton ? 0.4 : 0.2),
                    blurRadius: _isHoveringButton ? 20 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // আপনার রেজিস্ট্রেশন লজিক এখানে বসবে
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Text(
                      'রেজিস্ট্রেশন সম্পন্ন করুন',
                      style: GoogleFonts.hindSiliguri(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // লগইন লিংক
          Center(
            child: TextButton(
              onPressed: () {
                // ✅ pop এর বদলে pushReplacement ব্যবহার করুন
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(
                        isBangla:
                            true), // যেহেতু ওয়েব পেজটি বাংলায়, তাই true দেওয়া হলো
                  ),
                );
              },
              child: RichText(
                text: TextSpan(
                  text: 'আগে থেকেই অ্যাকাউন্ট আছে? ',
                  style: GoogleFonts.hindSiliguri(
                      color: secondaryText, fontSize: 15),
                  children: [
                    TextSpan(
                      text: 'লগইন করুন',
                      style: GoogleFonts.hindSiliguri(
                        color: primaryMaroon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ইনপুট ফিল্ড ডিজাইন
  // ============================================================
  Widget _buildPremiumField(String label, IconData icon,
      {bool isObscure = false}) {
    return TextFormField(
      obscureText: isObscure,
      style: GoogleFonts.hindSiliguri(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hindSiliguri(color: secondaryText),
        prefixIcon: Icon(icon, color: primaryMaroon.withValues(alpha: 0.7)),
        filled: true,
        fillColor: const Color(0xFFF9F9F9), // খুব হালকা ধূসর ব্যাকগ্রাউন্ড
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryMaroon, width: 2),
        ),
      ),
    );
  }
}
