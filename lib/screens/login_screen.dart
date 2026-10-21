import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ প্রিমিয়াম ফন্টের জন্য

import '../theme/colors.dart';
import '../utils/deactivate_service.dart';
import '../services/fcm_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';
import '../services/location_service.dart';
import 'package:flutter/foundation.dart'; // kIsWeb এর জন্য
import 'web_registration_screen.dart'; // আপনার নতুন ফাইলটি

// ============================================================
// LOGIN SCREEN
// ============================================================

class LoginScreen extends StatefulWidget {
  final bool isBangla;

  const LoginScreen({super.key, required this.isBangla});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoggingIn = false;
  bool _isHoveringButton = false; // ওয়েব হোভার ইফেক্টের জন্য

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: deepMaroon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Text(message),
      ),
    );
  }

  Future<void> _goToHome(bool bn) async {
    await FcmService.initialize();
    LocationService.saveLocationToFirestore();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(isBangla: bn)),
    );
  }

  Future<void> loginUser() async {
    final bn = widget.isBangla;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        bn ? 'ইমেইল ও পাসওয়ার্ড দিন।' : 'Please enter email and password.',
      );
      return;
    }

    setState(() {
      isLoggingIn = true;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) throw Exception('User null');

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return;

      if (!refreshedUser.emailVerified) {
        if (!mounted) return;
        setState(() => isLoggingIn = false);
        await _showUnverifiedDialog(bn, refreshedUser);
        return;
      }

      final isDeactivated = await DeactivateService.isDeactivated(user.uid);

      if (!mounted) return;

      if (isDeactivated) {
        setState(() => isLoggingIn = false);
        await _showReactivateDialog(bn);
        return;
      }

      await _goToHome(bn);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = bn ? 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই।' : 'No account found.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          message = bn ? 'পাসওয়ার্ড ভুল হয়েছে।' : 'Incorrect password.';
          break;
        case 'invalid-email':
          message = bn ? 'ইমেইল সঠিক নয়।' : 'Invalid email.';
          break;
        case 'user-disabled':
          message = bn ? 'অ্যাকাউন্ট নিষ্ক্রিয়।' : 'Account disabled.';
          break;
        case 'too-many-requests':
          message = bn ? 'অনেকবার চেষ্টা করেছেন।' : 'Too many attempts.';
          break;
        case 'network-request-failed':
          message = bn ? 'ইন্টারনেট চেক করুন।' : 'Check internet connection.';
          break;
        default:
          message = bn ? 'লগইন করা যায়নি।' : 'Could not log in.';
      }
      _showMessage(message);
    } catch (e) {
      _showMessage(bn ? 'সমস্যা হয়েছে।' : 'Something went wrong.');
    } finally {
      if (mounted) setState(() => isLoggingIn = false);
    }
  }

  Future<void> _showUnverifiedDialog(bool bn, User user) async {
    // ... (আপনার আগের Unverified Dialog কোডটি এখানে বসান, আমি নিচে সংক্ষেপে দিয়েছি)
    bool isSending = false;
    bool isChecking = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                backgroundColor: warmWhite,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.mark_email_unread_outlined,
                              color: Colors.orange, size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text(bn ? 'Email verify করুন' : 'Verify Your Email',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: deepMaroon)),
                        const SizedBox(height: 10),
                        Text(
                            bn
                                ? 'আপনার email এখনো verify হয়নি।'
                                : 'Your email is not verified yet.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: secondaryText,
                                height: 1.5)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isChecking
                                ? null
                                : () async {
                                    setDialogState(() => isChecking = true);
                                    try {
                                      await user.reload();
                                      final u =
                                          FirebaseAuth.instance.currentUser;
                                      if (u != null && u.emailVerified) {
                                        if (!dialogContext.mounted) return;
                                        Navigator.pop(dialogContext);
                                        final isDeactivated =
                                            await DeactivateService
                                                .isDeactivated(u.uid);
                                        if (!mounted) return;
                                        if (isDeactivated) {
                                          await _showReactivateDialog(bn);
                                        } else {
                                          await _goToHome(bn);
                                        }
                                      } else {
                                        setDialogState(
                                            () => isChecking = false);
                                        _showMessage(bn
                                            ? '⚠️ এখনো verify হয়নি।'
                                            : '⚠️ Not verified yet.');
                                      }
                                    } catch (_) {
                                      setDialogState(() => isChecking = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: isChecking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white)))
                                : Text(
                                    bn ? 'আমি verify করেছি' : 'I have verified',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: isSending
                                ? null
                                : () async {
                                    setDialogState(() => isSending = true);
                                    try {
                                      await user.sendEmailVerification();
                                      if (!mounted) return;
                                      _showMessage(bn
                                          ? '✅ Email পাঠানো হয়েছে'
                                          : '✅ Email sent');
                                    } catch (_) {
                                      _showMessage(bn
                                          ? 'পাঠানো যায়নি'
                                          : 'Could not send');
                                    } finally {
                                      setDialogState(() => isSending = false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                                foregroundColor: primaryMaroon,
                                side: BorderSide(
                                    color: primaryMaroon.withValues(alpha: 0.5),
                                    width: 1.4),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                primaryMaroon)))
                                : Text(bn ? 'Email আবার পাঠান' : 'Resend Email',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                          },
                          child: Text(
                              bn
                                  ? 'অন্য email দিয়ে try করব'
                                  : 'Try a different email',
                              style: const TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReactivateDialog(bool bn) async {
    // ... (আপনার আগের Reactivate Dialog কোডটি এখানে বসান, আমি সংক্ষেপে দিয়েছি)
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: warmWhite,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.pause_circle_outline,
                        color: Colors.orange, size: 40)),
                const SizedBox(height: 14),
                Text(bn ? 'Account Deactivated' : 'Account Deactivated',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: deepMaroon)),
                const SizedBox(height: 10),
                Text(
                    bn
                        ? 'আপনার অ্যাকাউন্টটি deactivated ছিল। এটি আবার চালু করতে চান?'
                        : 'Your account was deactivated. Reactivate?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: secondaryText, height: 1.5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(
                                    color: primaryMaroon, width: 1.3),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text(bn ? 'না, লগআউট' : 'No, Logout',
                                style: const TextStyle(
                                    color: primaryMaroon,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)))),
                    const SizedBox(width: 10),
                    Expanded(
                        flex: 2,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primaryMaroon,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: Text(
                                bn ? 'হ্যাঁ, চালু করুন' : 'Yes, Reactivate',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      await _reactivateAccount(bn);
    } else {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showMessage(bn ? 'লগআউট করা হয়েছে।' : 'Logged out.');
    }
  }

  Future<void> _reactivateAccount(bool bn) async {
    setState(() => isLoggingIn = true);
    final result = await DeactivateService.reactivateAccount();
    if (!mounted) return;
    setState(() => isLoggingIn = false);

    if (result['success'] == true) {
      _showMessage(bn
          ? '🎉 আপনার অ্যাকাউন্ট আবার চালু হয়েছে!'
          : '🎉 Account reactivated!');
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await _goToHome(bn);
    } else {
      _showMessage(bn ? 'Reactivate করা যায়নি।' : 'Could not reactivate.');
      await FirebaseAuth.instance.signOut();
    }
  }

  // ============================================================
  // BUILD (মোবাইল এবং ওয়েব ভিউ আলাদা করা হলো)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      body: kIsWeb ? _buildWebLayout(bn) : _buildMobileLayout(bn),
    );
  }

  // ============================================================
  // 📱 মোবাইল লেআউট (আপনার আগের ডিজাইন)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: primaryMaroon),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: primaryGold.withValues(alpha: .12),
                      blurRadius: 25,
                      spreadRadius: 3)
                ],
              ),
              child: Image.asset('assets/logo.png',
                  width: 130, height: 130, fit: BoxFit.contain),
            ),
            const SizedBox(height: 28),
            Text(
              bn
                  ? 'আবার আপনাকে দেখে ভালো লাগছে ❤️'
                  : 'Good to see you again ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: bn ? 24 : 27,
                  fontWeight: FontWeight.w800,
                  color: mainText),
            ),
            const SizedBox(height: 8),
            Text(
              bn
                  ? 'আপনার সুন্দর যাত্রা অপেক্ষা করছে।'
                  : 'Your beautiful journey is waiting.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: secondaryText, fontSize: 15),
            ),
            const SizedBox(height: 35),
            _buildEmailField(bn),
            const SizedBox(height: 15),
            _buildPasswordField(bn),
            const SizedBox(height: 8),
            _buildForgotPassword(bn),
            const SizedBox(height: 12),
            _buildLoginButton(bn),
            const SizedBox(height: 25),
            _buildOrDivider(bn),
            const SizedBox(height: 18),
            _buildRegisterButton(bn),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 💻 ওয়েব লেআউট (প্রিমিয়াম স্প্লিট স্ক্রিন)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    return Row(
      children: [
        // 🟢 বাম দিকের ব্র্যান্ডিং সেকশন
        Expanded(
          flex: 6,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B1E3F), Color(0xFF5E1128)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png',
                      width: 120, height: 120, fit: BoxFit.contain),
                  const SizedBox(height: 30),
                  Text(
                    bn ? 'আবার স্বাগতম' : 'Welcome Back',
                    style: GoogleFonts.hindSiliguri(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    bn
                        ? 'আপনার জীবনসাথী আপনার অপেক্ষায় আছে।'
                        : 'Your life partner is waiting for you.',
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 20, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ⚪ ডান দিকের ফর্ম সেকশন (Glassmorphism)
        Expanded(
          flex: 5,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: primaryMaroon.withValues(alpha: 0.08),
                        blurRadius: 40,
                        offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bn ? 'লগইন করুন' : 'Login',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: deepMaroon),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bn
                          ? 'আপনার অ্যাকাউন্টে প্রবেশ করুন।'
                          : 'Enter your account.',
                      style: GoogleFonts.hindSiliguri(
                          fontSize: 16, color: secondaryText),
                    ),
                    const SizedBox(height: 32),

                    _buildEmailField(bn),
                    const SizedBox(height: 20),
                    _buildPasswordField(bn),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoggingIn
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      isBangla: bn,
                                      prefilledEmail:
                                          emailController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          bn ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot password?',
                          style: GoogleFonts.hindSiliguri(
                              color: deepMaroon, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // প্রিমিয়াম লগইন বাটন
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
                                : [const Color(0xFF9C27B0), primaryMaroon],
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
                            onTap: isLoggingIn ? null : loginUser,
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: isLoggingIn
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      bn ? 'লগইন করুন' : 'Login',
                                      style: GoogleFonts.hindSiliguri(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    _buildOrDivider(bn),
                    const SizedBox(height: 20),
                    _buildRegisterButton(bn),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // রিইউজেবল উইজেটস (মোবাইল এবং ওয়েব উভয়ের জন্য)
  // ============================================================
  Widget _buildEmailField(bool bn) {
    return TextField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: bn ? 'ইমেইল' : 'Email',
        prefixIcon: const Icon(Icons.email_outlined, color: primaryMaroon),
        filled: true,
        fillColor: warmWhite,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryMaroon, width: 1.5)),
      ),
    );
  }

  Widget _buildPasswordField(bool bn) {
    return TextField(
      controller: passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: bn ? 'পাসওয়ার্ড' : 'Password',
        prefixIcon: const Icon(Icons.lock_outline, color: primaryMaroon),
        filled: true,
        fillColor: warmWhite,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryMaroon, width: 1.5)),
      ),
    );
  }

  Widget _buildForgotPassword(bool bn) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: isLoggingIn
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordScreen(
                        isBangla: bn,
                        prefilledEmail: emailController.text.trim()),
                  ),
                );
              },
        child: Text(bn ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot password?',
            style: const TextStyle(
                color: deepMaroon, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildLoginButton(bool bn) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFC59B4B), Color(0xFF8B1E3F)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: .22),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoggingIn ? null : loginUser,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20))),
          child: isLoggingIn
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(bn ? 'লগইন করুন' : 'Login',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildOrDivider(bool bn) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(bn ? 'অথবা' : 'or',
              style: TextStyle(color: Colors.grey.shade500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildRegisterButton(bool bn) {
    return TextButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) {
              // ✅ এখানেই kIsWeb চেক করা হলো
              if (kIsWeb) {
                return const WebRegistrationScreen();
              } else {
                return RegistrationScreen(isBangla: bn);
              }
            },
          ),
        );
      },
      child: Text(
        bn ? 'নতুন? আপনার প্রোফাইল তৈরি করুন' : 'New here? Create your profile',
        style: const TextStyle(
            color: deepMaroon, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
