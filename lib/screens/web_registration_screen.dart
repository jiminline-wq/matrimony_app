import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

class WebRegistrationScreen extends StatefulWidget {
  // ✅ ক্লাসের নাম পরিবর্তন করা হলো
  const WebRegistrationScreen({super.key});

  @override
  State<WebRegistrationScreen> createState() => _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends State<WebRegistrationScreen> {
  bool _isHoveringButton = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FA), // খুব হালকা প্রিমিয়াম ব্যাকগ্রাউন্ড
      body: LayoutBuilder(
        builder: (context, constraints) {
          // মোবাইলের জন্য আলাদা লজিক (এখানে শুধু ওয়েব ডিজাইন দেখাচ্ছি)
          if (constraints.maxWidth < 900) {
            return const Center(
                child: Text("Mobile View (Please use Web Version)"));
          }
          return _buildPremiumWebLayout();
        },
      ),
    );
  }

  Widget _buildPremiumWebLayout() {
    return Stack(
      children: [
        // ১. ব্যাকগ্রাউন্ড ডিজাইন (সূক্ষ্ম প্যাটার্ন বা গ্রেডিয়েন্ট)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)],
              ),
            ),
          ),
        ),

        // ২. মূল কন্টেন্ট
        Column(
          children: [
            _buildWebNavbar(), // উপরের নেভিগেশন বার

            Expanded(
              child: Row(
                children: [
                  // বাম দিকের অংশ (ব্র্যান্ডিং)
                  Expanded(
                    flex: 6,
                    child: _buildLeftHeroSection(),
                  ),

                  // ডান দিকের অংশ (রেজিস্ট্রেশন ফর্ম)
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 20),
                        child: _buildGlassFormCard(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildFooter(), // নিচের ফুটার
          ],
        ),
      ],
    );
  }

  // ============================================================
  // 🟢 বাম দিকের হিরো সেকশন (Branding)
  // ============================================================
  Widget _buildLeftHeroSection() {
    return Padding(
      padding: const EdgeInsets.all(60.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: primaryGold.withOpacity(0.5)),
            ),
            child: const Text(
              'বিশ্বস্ত ম্যাট্রিমনি',
              style: TextStyle(
                  color: deepMaroon, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'জীবনসাথী খুঁজুন\nসহজে ও নিরাপদে',
            style: GoogleFonts.hindSiliguri(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: deepMaroon,
              height: 1.2,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'হাজারো ভেরিফাইড প্রোফাইল থেকে খুঁজে নিন আপনার পছন্দের মানুষ।\nআজই যুক্ত হোন আমাদের পরিবারে।',
            style: GoogleFonts.hindSiliguri(
              fontSize: 20,
              color: secondaryText,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),

          // ট্রাস্ট ইন্ডিকেটর
          Row(
            children: [
              _buildTrustIndicator(Icons.verified_user, '১০০% ভেরিফাইড'),
              const SizedBox(width: 30),
              _buildTrustIndicator(Icons.security, 'সুরক্ষিত ডেটা'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustIndicator(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.hindSiliguri(
              fontSize: 16, fontWeight: FontWeight.w600, color: mainText),
        ),
      ],
    );
  }

  // ============================================================
  // ⚪ ডান দিকের গ্লাস ফর্ম কার্ড (Glassmorphism)
  // ============================================================
  Widget _buildGlassFormCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), // হালকা স্বচ্ছ সাদা
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withOpacity(0.08),
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
                fontSize: 32, fontWeight: FontWeight.bold, color: deepMaroon),
          ),
          const SizedBox(height: 8),
          Text(
            'আপনার তথ্য দিয়ে অ্যাকাউন্ট তৈরি করুন।',
            style: GoogleFonts.hindSiliguri(fontSize: 16, color: secondaryText),
          ),
          const SizedBox(height: 32),

          _buildPremiumField('আপনার পুরো নাম', Icons.person_outline),
          const SizedBox(height: 20),
          _buildPremiumField('ইমেইল অ্যাড্রেস', Icons.email_outlined),
          const SizedBox(height: 20),
          _buildPremiumField('মোবাইল নম্বর', Icons.phone_outlined),
          const SizedBox(height: 20),
          _buildPremiumField('পাসওয়ার্ড', Icons.lock_outline, isObscure: true),

          const SizedBox(height: 32),

          // প্রিমিয়াম হোভার বাটন
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringButton = true),
            onExit: (_) => setState(() => _isHoveringButton = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isHoveringButton
                      ? [primaryMaroon, deepMaroon]
                      : [
                          const Color(0xFF9C27B0),
                          primaryMaroon
                        ], // প্রিমিয়াম গ্রেডিয়েন্ট
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: primaryMaroon
                        .withOpacity(_isHoveringButton ? 0.4 : 0.2),
                    blurRadius: _isHoveringButton ? 20 : 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // আপনার রেজিস্ট্রেশন লজিক এখানে
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
        prefixIcon: Icon(icon, color: primaryMaroon.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white,
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

  // ============================================================
  // টপ নেভিগেশন বার (Navbar)
  // ============================================================
  Widget _buildWebNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
      color: Colors.white.withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: primaryMaroon, size: 32),
              const SizedBox(width: 10),
              Text(
                'জীবনসাথী',
                style: GoogleFonts.hindSiliguri(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: deepMaroon,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavText('হোম'),
              _buildNavText('প্রোফাইল'),
              _buildNavText('সফলতার গল্প'),
              const SizedBox(width: 20),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryMaroon),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('লগইন',
                    style: GoogleFonts.hindSiliguri(
                        color: primaryMaroon, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNavText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: GoogleFonts.hindSiliguri(
            fontSize: 16, fontWeight: FontWeight.w500, color: mainText),
      ),
    );
  }

  // ============================================================
  // নিচের ফুটার (Footer)
  // ============================================================
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '© ২০২৬ জীবনসাথী ম্যাট্রিমনি। সর্বস্বত্ব সংরক্ষিত।',
            style: GoogleFonts.hindSiliguri(fontSize: 14, color: secondaryText),
          ),
          Row(
            children: [
              TextButton(
                  onPressed: () {},
                  child: Text('প্রাইভেসি পলিসি',
                      style: GoogleFonts.hindSiliguri(color: secondaryText))),
              TextButton(
                  onPressed: () {},
                  child: Text('টার্মস অ্যান্ড কন্ডিশনস',
                      style: GoogleFonts.hindSiliguri(color: secondaryText))),
            ],
          )
        ],
      ),
    );
  }
}
