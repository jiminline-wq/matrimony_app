import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ ওয়েবের প্রিমিয়াম ফন্টের জন্য

import '../theme/colors.dart';
import 'registration_screen.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart'; // kIsWeb এর জন্য
import 'web_registration_screen.dart'; // আপনার নতুন ফাইলটি

// ============================================================
// LANGUAGE
// ============================================================

class AppLanguage extends ChangeNotifier {
  bool isBangla = true;
  void toggle() {
    isBangla = !isBangla;
    notifyListeners();
  }
}

class FloatingLogo {
  final double left;
  final double top;
  final double size;
  final double opacity;
  final double rotation;

  FloatingLogo({
    required this.left,
    required this.top,
    required this.size,
    required this.opacity,
    required this.rotation,
  });
}

// ============================================================
// WELCOME SCREEN
// ============================================================

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  final AppLanguage language = AppLanguage();

  final List<FloatingLogo> logos = [
    FloatingLogo(left: 35, top: 110, size: 30, opacity: .18, rotation: -.2),
    FloatingLogo(left: 300, top: 150, size: 40, opacity: .15, rotation: .2),
    FloatingLogo(left: 70, top: 300, size: 25, opacity: .13, rotation: .3),
    FloatingLogo(left: 330, top: 330, size: 35, opacity: .16, rotation: -.3),
    FloatingLogo(left: 25, top: 500, size: 45, opacity: .11, rotation: .2),
    FloatingLogo(left: 350, top: 560, size: 30, opacity: .13, rotation: -.2),
  ];

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    animationController.dispose();
    language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: language,
      builder: (context, child) {
        final bool bn = language.isBangla;

        // ✅ এখানে চেক করা হচ্ছে এটি ওয়েব কিনা
        if (kIsWeb) {
          return _buildWebLayout(bn);
        }

        // ✅ মোবাইলের জন্য আপনার আগের ডিজাইন হুবহু
        return _buildMobileLayout(bn);
      },
    );
  }

  // ============================================================
  // 💻 ওয়েবের জন্য রোমান্টিক ও প্রিমিয়াম ডিজাইন
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: Row(
        children: [
          // 🟢 বাম দিকের অংশ (রোমান্টিক ভিজ্যুয়াল)
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7EBEE),
                    Color(0xFFFDFBF7),
                    Color(0xFFFBF5E8)
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // ফ্লোটিং হার্ট অ্যানিমেশন
                  ...List.generate(8, (index) {
                    return AnimatedBuilder(
                      animation: animationController,
                      builder: (context, child) {
                        final movement = math.sin(
                                animationController.value * math.pi * 2 +
                                    index) *
                            15;
                        return Positioned(
                          left: (index * 120.0) %
                              MediaQuery.of(context).size.width *
                              0.5,
                          top: 100 + (index * 80.0) + movement,
                          child: Opacity(
                            opacity: 0.05 + (index * 0.02),
                            child: const Icon(Icons.favorite,
                                size: 60, color: primaryMaroon),
                          ),
                        );
                      },
                    );
                  }),

                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: animationController,
                          builder: (context, child) {
                            final scale = 1 +
                                math.sin(animationController.value *
                                        math.pi *
                                        2) *
                                    .03;
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGold.withValues(alpha: .2),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 220,
                              height: 220,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          bn ? 'জীবন সাথী' : 'Jibon Sathi',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          bn
                              ? 'আমার শূন্যতা কাটুক তোমার আগমনে'
                              : 'May your arrival fill my emptiness',
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 24,
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ⚪ ডান দিকের অংশ (লগইন / রেজিস্ট্রেশন বাটন)
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Stack(
                children: [
                  // ল্যাঙ্গুয়েজ টগল (উপরে ডানদিকে)
                  Positioned(
                    top: 30,
                    right: 30,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _languageButton(
                              text: 'বাংলা',
                              selected: bn,
                              onTap: () {
                                if (!bn) language.toggle();
                              }),
                          _languageButton(
                              text: 'English',
                              selected: !bn,
                              onTap: () {
                                if (bn) language.toggle();
                              }),
                        ],
                      ),
                    ),
                  ),

                  // মূল কন্টেন্ট
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 50),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bn ? 'স্বাগতম 👋' : 'Welcome 👋',
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: deepMaroon,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            bn
                                ? 'হাজারো ভেরিফাইড প্রোফাইল থেকে খুঁজে নিন আপনার পছন্দের মানুষ। আজই যুক্ত হোন আমাদের পরিবারে।'
                                : 'Find your perfect match from thousands of verified profiles. Join our family today.',
                            style: GoogleFonts.hindSiliguri(
                              fontSize: 16,
                              color: secondaryText,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // রেজিস্ট্রেশন বাটন
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFC59B4B),
                                    Color(0xFF8B1E3F)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryMaroon.withValues(alpha: .3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const WebRegistrationScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      bn
                                          ? 'আপনার যাত্রা শুরু করুন'
                                          : 'Begin Your Journey',
                                      style: GoogleFonts.hindSiliguri(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.arrow_forward_rounded),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // লগইন বাটন
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(isBangla: bn),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryMaroon,
                                side: BorderSide(
                                  color: primaryMaroon.withValues(alpha: .5),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                bn
                                    ? 'আমার অ্যাকাউন্ট আছে'
                                    : 'I Already Have an Account',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // প্রাইভেসি নোট
                          Row(
                            children: [
                              const Icon(Icons.verified_user_outlined,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                bn
                                    ? 'আপনার গোপনীয়তা, আপনার পছন্দ'
                                    : 'Your privacy, your choice',
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  // ============================================================
  // 📱 মোবাইল লেআউট (আপনার আগের কোড, কোনো পরিবর্তন নেই)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDFBF7),
              Color(0xFFFBF5E8),
              Color(0xFFF7EBEE),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ...logos.map(
                (logo) => AnimatedBuilder(
                  animation: animationController,
                  builder: (context, child) {
                    final movement = math.sin(
                          animationController.value * math.pi * 2,
                        ) *
                        8;
                    return Positioned(
                      left: logo.left,
                      top: logo.top + movement,
                      child: Transform.rotate(
                        angle: logo.rotation,
                        child: Opacity(
                          opacity: logo.opacity,
                          child: Image.asset(
                            'assets/logo.png',
                            width: logo.size,
                            height: logo.size,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(
                              color: primaryMaroon.withValues(alpha: .08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _languageButton(
                              text: 'বাংলা',
                              selected: bn,
                              onTap: () {
                                if (!bn) language.toggle();
                              },
                            ),
                            _languageButton(
                              text: 'English',
                              selected: !bn,
                              onTap: () {
                                if (bn) language.toggle();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    AnimatedBuilder(
                      animation: animationController,
                      builder: (context, child) {
                        final scale = 1 +
                            math.sin(
                                  animationController.value * math.pi * 2,
                                ) *
                                .025;
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryGold.withValues(alpha: .14),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 175,
                          height: 175,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      bn ? 'জীবন সাথী' : 'Jibon Sathi',
                      style: TextStyle(
                        fontSize: bn ? 40 : 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: bn ? 0 : -1,
                        color: mainText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bn
                          ? 'আমার শূন্যতা কাটুক তোমার আগমনে'
                          : 'May your arrival fill my emptiness',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: bn ? 18 : 17,
                        height: 1.5,
                        color: secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .68),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryMaroon.withValues(alpha: .06),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 16,
                            color: primaryMaroon,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bn ? 'অর্থবহ সম্পর্ক' : 'Meaningful connections',
                            style: const TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFC59B4B),
                              Color(0xFF8B1E3F),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryMaroon.withValues(alpha: .25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RegistrationScreen(isBangla: bn),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                bn
                                    ? 'আপনার যাত্রা শুরু করুন'
                                    : 'Begin Your Journey',
                                style: TextStyle(
                                  fontSize: bn ? 16 : 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(isBangla: bn),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: deepMaroon,
                          side: BorderSide(
                            color: primaryMaroon.withValues(alpha: .5),
                            width: 1.5,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: .50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          bn
                              ? 'আমার অ্যাকাউন্ট আছে'
                              : 'I Already Have an Account',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            bn
                                ? 'আপনার গোপনীয়তা, আপনার পছন্দ'
                                : 'Your privacy, your choice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageButton({
    required String text,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primaryMaroon : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : deepMaroon,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
