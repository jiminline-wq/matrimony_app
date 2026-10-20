import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../utils/deactivate_service.dart';
import '../services/fcm_service.dart';
import 'home_screen.dart';
import 'registration_screen.dart';
import 'forgot_password_screen.dart';
import '../services/location_service.dart';

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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // SHOW SNACKBAR MESSAGE
  // ============================================================

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

  // ============================================================
  // NAVIGATE TO HOME (FCM token save সহ)
  // ============================================================

  Future<void> _goToHome(bool bn) async {
    // ✅ FCM token save করুন (login এর পর)
    await FcmService.initialize();

    // ✅ Location save করুন (background এ, UI block করবে না)
    LocationService.saveLocationToFirestore();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(isBangla: bn)),
    );
  }

  // ============================================================
  // LOGIN WITH FIREBASE AUTH
  // Flow:
  //   1. Sign in
  //   2. Email verified check  → unverified হলে dialog
  //   3. Deactivated check     → deactivated হলে reactivate dialog
  //   4. FCM token save + Home এ যাও
  // ============================================================

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

      // ✅ Fresh status reload
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return;

      // ========================================================
      // STEP 1 — Email verified check
      // ========================================================
      if (!refreshedUser.emailVerified) {
        if (!mounted) return;
        setState(() => isLoggingIn = false);
        await _showUnverifiedDialog(bn, refreshedUser);
        return;
      }

      // ========================================================
      // STEP 2 — Deactivated check
      // ========================================================
      final isDeactivated = await DeactivateService.isDeactivated(user.uid);

      if (!mounted) return;

      if (isDeactivated) {
        setState(() => isLoggingIn = false);
        await _showReactivateDialog(bn);
        return;
      }

      // ========================================================
      // STEP 3 — FCM init + Home এ যাও
      // ========================================================
      await _goToHome(bn);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = bn
              ? 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই।'
              : 'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = bn ? 'পাসওয়ার্ড ভুল হয়েছে।' : 'Incorrect password.';
          break;

        case 'invalid-email':
          message = bn
              ? 'ইমেইল ঠিকানাটি সঠিক নয়।'
              : 'The email address is not valid.';
          break;

        case 'user-disabled':
          message = bn
              ? 'এই অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে।'
              : 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = bn
              ? 'অনেকবার চেষ্টা করেছেন। কিছুক্ষণ পরে আবার চেষ্টা করুন।'
              : 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = bn
              ? 'ইন্টারনেট সংযোগ পরীক্ষা করুন।'
              : 'Please check your internet connection.';
          break;

        case 'operation-not-allowed':
          message = bn
              ? 'Email/Password login Firebase-এ এখনো সক্রিয় করা হয়নি।'
              : 'Email/Password authentication is not enabled in Firebase.';
          break;

        default:
          message = bn
              ? 'লগইন করা যায়নি। আবার চেষ্টা করুন।'
              : 'Could not log in. Please try again.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage(
        bn
            ? 'একটি সমস্যা হয়েছে। আবার চেষ্টা করুন।'
            : 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoggingIn = false;
        });
      }
    }
  }

  // ============================================================
  // UNVERIFIED EMAIL DIALOG
  // ============================================================

  Future<void> _showUnverifiedDialog(bool bn, User user) async {
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
                  borderRadius: BorderRadius.circular(22),
                ),
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
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: Colors.orange,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          bn ? 'Email verify করুন' : 'Verify Your Email',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bn
                              ? 'আপনার email এখনো verify হয়নি। Inbox এ verification link আছে।'
                              : 'Your email is not verified yet. Please check your inbox for the verification link.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: secondaryText,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryMaroon.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: primaryMaroon,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  user.email ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // I have verified
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

                                        // Deactivated check
                                        final isDeactivated =
                                            await DeactivateService.isDeactivated(
                                              u.uid,
                                            );

                                        if (!mounted) return;

                                        if (isDeactivated) {
                                          await _showReactivateDialog(bn);
                                        } else {
                                          // ✅ FCM init + Home
                                          await _goToHome(bn);
                                        }
                                      } else {
                                        setDialogState(
                                          () => isChecking = false,
                                        );
                                        _showMessage(
                                          bn
                                              ? '⚠️ এখনো verify হয়নি। Inbox চেক করুন।'
                                              : '⚠️ Not verified yet. Check inbox.',
                                        );
                                      }
                                    } catch (_) {
                                      setDialogState(() => isChecking = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryMaroon,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isChecking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        bn
                                            ? 'আমি verify করেছি'
                                            : 'I have verified',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Resend
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
                                      _showMessage(
                                        bn
                                            ? '✅ Email আবার পাঠানো হয়েছে'
                                            : '✅ Email sent again',
                                      );
                                    } catch (_) {
                                      _showMessage(
                                        bn ? 'পাঠানো যায়নি' : 'Could not send',
                                      );
                                    } finally {
                                      setDialogState(() => isSending = false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryMaroon,
                              side: BorderSide(
                                color: primaryMaroon.withValues(alpha: 0.5),
                                width: 1.4,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        primaryMaroon,
                                      ),
                                    ),
                                  )
                                : Text(
                                    bn ? 'Email আবার পাঠান' : 'Resend Email',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Logout
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  // ============================================================
  // REACTIVATE DIALOG
  // ============================================================

  Future<void> _showReactivateDialog(bool bn) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_circle_outline,
                    color: Colors.orange,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  bn ? 'Account Deactivated' : 'Account Deactivated',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bn
                      ? 'আপনার অ্যাকাউন্টটি deactivated ছিল। এটি আবার চালু করতে চান?'
                      : 'Your account was deactivated. Do you want to reactivate it?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightGold,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: deepGold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bn
                              ? 'Reactivate করলে আবার সবাই আপনাকে দেখতে পাবে।'
                              : 'Once reactivated, everyone can see you again.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: mainText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: primaryMaroon,
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          bn ? 'না, লগআউট' : 'No, Logout',
                          style: const TextStyle(
                            color: primaryMaroon,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryMaroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          bn ? 'হ্যাঁ, চালু করুন' : 'Yes, Reactivate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
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
      _showMessage(
        bn
            ? 'লগআউট করা হয়েছে। আবার চেষ্টা করুন।'
            : 'Logged out. Please try again.',
      );
    }
  }

  // ============================================================
  // REACTIVATE ACCOUNT
  // ============================================================

  Future<void> _reactivateAccount(bool bn) async {
    setState(() => isLoggingIn = true);

    final result = await DeactivateService.reactivateAccount();

    if (!mounted) return;

    setState(() => isLoggingIn = false);

    if (result['success'] == true) {
      _showMessage(
        bn
            ? '🎉 আপনার অ্যাকাউন্ট আবার চালু হয়েছে!'
            : '🎉 Your account is now active!',
      );

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // ✅ FCM init + Home
      await _goToHome(bn);
    } else {
      _showMessage(
        bn
            ? 'Reactivate করা যায়নি। আবার চেষ্টা করুন।'
            : 'Could not reactivate. Please try again.',
      );

      await FirebaseAuth.instance.signOut();
    }
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
          bn ? 'স্বাগতম' : 'Welcome Back',
          style: const TextStyle(fontWeight: FontWeight.bold, color: mainText),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 25),

            // Logo
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryGold.withValues(alpha: .12),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo.png',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 28),

            // Welcome text
            Text(
              bn
                  ? 'আবার আপনাকে দেখে ভালো লাগছে ❤️'
                  : 'Good to see you again ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: bn ? 24 : 27,
                fontWeight: FontWeight.w800,
                color: mainText,
              ),
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

            // Email
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: bn ? 'ইমেইল' : 'Email',
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: primaryMaroon,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: primaryMaroon,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Password
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: bn ? 'পাসওয়ার্ড' : 'Password',
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: primaryMaroon,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: primaryMaroon,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Forgot password
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
                              prefilledEmail: emailController.text.trim(),
                            ),
                          ),
                        );
                      },
                child: Text(
                  bn ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot password?',
                  style: const TextStyle(
                    color: deepMaroon,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 58,
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
                  onPressed: isLoggingIn ? null : loginUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isLoggingIn
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
                      : Text(
                          bn ? 'লগইন করুন' : 'Login',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // OR divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    bn ? 'অথবা' : 'or',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),

            const SizedBox(height: 18),

            // Create account
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegistrationScreen(isBangla: bn),
                  ),
                );
              },
              child: Text(
                bn
                    ? 'নতুন? আপনার প্রোফাইল তৈরি করুন'
                    : 'New here? Create your profile',
                style: const TextStyle(
                  color: deepMaroon,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
