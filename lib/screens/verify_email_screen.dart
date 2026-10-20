import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/colors.dart';
import 'profile_setup_screen.dart';
import 'welcome_screen.dart';

// ============================================================
// VERIFY EMAIL SCREEN
// Registration এর পর এই screen এ আসবে
// User email verify না করা পর্যন্ত ProfileSetup এ যেতে পারবে না
// ============================================================

class VerifyEmailScreen extends StatefulWidget {
  final bool isBangla;

  // Registration এর data — verify হওয়ার পর ProfileSetup এ pass করব
  final String name;
  final String gender;
  final String religion;
  final String email;
  final String phone;

  const VerifyEmailScreen({
    super.key,
    required this.isBangla,
    required this.name,
    required this.gender,
    required this.religion,
    required this.email,
    required this.phone,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Screen খোলার সময় automatically resend করি (optional)
    // _resendEmail();
  }

  // ============================================================
  // RESEND VERIFICATION EMAIL
  // ============================================================

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage(
          widget.isBangla ? 'আপনি লগইন করা নেই।' : 'You are not logged in.',
        );
        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;

      _showMessage(
        widget.isBangla
            ? '✅ Verification email আবার পাঠানো হয়েছে'
            : '✅ Verification email sent again',
        success: true,
      );

      // 60 সেকেন্ড cooldown
      setState(() => _resendCooldown = 60);
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        widget.isBangla
            ? 'Email পাঠানো যায়নি। আবার চেষ্টা করুন।'
            : 'Could not send email. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _startCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
        _startCooldown();
      }
    });
  }

  // ============================================================
  // CHECK VERIFICATION
  // ============================================================

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        _showMessage(
            widget.isBangla ? 'আপনি লগইন করা নেই।' : 'You are not logged in.');
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return;

      if (!refreshedUser.emailVerified) {
        if (!mounted) return;
        _showMessage(widget.isBangla
            ? '⚠️ এখনো verify হয়নি। আপনার inbox চেক করুন।'
            : '⚠️ Not verified yet.');
        return;
      }

      // ✅ VERIFIED! এখন Firestore থেকে user data reload করি
      // কারণ app kill হলে constructor params হারিয়ে গেছে
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid)
          .get();

      if (!mounted) return;

      final data = userDoc.data() ?? {};

      // ✅ Firestore-এ data আছে → সেটা দিয়ে ProfileSetup-এ যাই
      // না থাকলে constructor param fallback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            isBangla: widget.isBangla,
            name: (data['name'] ?? widget.name).toString(),
            gender: (data['gender'] ?? widget.gender).toString(),
            religion: (data['religion'] ?? widget.religion).toString(),
            email: (data['email'] ?? widget.email).toString(),
            phone: (data['phone'] ?? widget.phone).toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ _checkVerification error: $e');
      _showMessage(widget.isBangla
          ? 'চেক করা যায়নি। আবার চেষ্টা করুন।'
          : 'Could not check.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }
  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          widget.isBangla ? 'লগআউট করবেন?' : 'Logout?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          widget.isBangla
              ? 'আপনি চাইলে পরে আবার email verify করতে পারবেন।'
              : 'You can verify your email later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              widget.isBangla ? 'বাতিল' : 'Cancel',
              style: const TextStyle(color: secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              widget.isBangla ? 'লগআউট' : 'Logout',
              style: const TextStyle(
                color: primaryMaroon,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(String msg, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? Colors.green.shade700 : deepMaroon,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        duration: const Duration(seconds: 3),
        content: Text(msg),
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
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          bn ? 'ইমেইল যাচাই' : 'Verify Email',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: deepMaroon),
            tooltip: bn ? 'লগআউট' : 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Icon
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: lightMaroon,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryMaroon.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_unread_outlined,
                size: 60,
                color: primaryMaroon,
              ),
            ),

            const SizedBox(height: 30),

            Text(
              bn ? '📩 আপনার ইমেইল চেক করুন' : '📩 Check Your Email',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: bn ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: mainText,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              bn
                  ? 'আমরা একটি verification link পাঠিয়েছি।\nলিংকে ক্লিক করে আপনার account চালু করুন।'
                  : 'We\'ve sent a verification link.\nClick the link to activate your account.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: secondaryText,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 20),

            // Email pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryMaroon.withValues(alpha: 0.2),
                  width: 1.3,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: primaryMaroon,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mainText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: lightGold,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: deepGold,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bn
                          ? 'Inbox এ না পেলে Spam / Promotions folder চেক করুন।'
                          : 'If not in inbox, check your Spam / Promotions folder.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: mainText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // I've verified button
            SizedBox(
              width: double.infinity,
              height: 58,
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
                      color: primaryMaroon.withValues(alpha: .22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              bn ? 'আমি verify করেছি' : 'I have verified',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Resend button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed:
                    (_isResending || _resendCooldown > 0) ? null : _resendEmail,
                icon: _isResending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryMaroon),
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _resendCooldown > 0
                      ? (bn
                          ? 'আবার পাঠান ($_resendCooldown সেকেন্ড)'
                          : 'Resend in $_resendCooldown s')
                      : (bn ? 'Email আবার পাঠান' : 'Resend Email'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryMaroon,
                  side: BorderSide(
                    color: primaryMaroon.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Logout text
            TextButton(
              onPressed: _logout,
              child: Text(
                bn ? 'অন্য email দিয়ে try করবেন?' : 'Try a different email?',
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
    );
  }
}
