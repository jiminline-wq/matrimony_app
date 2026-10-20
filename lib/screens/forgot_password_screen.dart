import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';

// ============================================================
// FORGOT PASSWORD SCREEN
// ============================================================

class ForgotPasswordScreen extends StatefulWidget {
  final bool isBangla;
  final String? prefilledEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.isBangla,
    this.prefilledEmail,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool isSending = false;
  bool emailSent = false;
  int resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      emailController.text = widget.prefilledEmail!;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND RESET EMAIL
  // ============================================================

  Future<void> _sendResetEmail() async {
    final bn = widget.isBangla;

    if (!formKey.currentState!.validate()) return;

    setState(() => isSending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        emailSent = true;
        isSending = false;
        resendCooldown = 60;
      });

      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = bn
              ? 'এই ইমেইলে কোনো অ্যাকাউন্ট নেই।'
              : 'No account found with this email.';
          break;
        case 'invalid-email':
          message = bn
              ? 'ইমেইল ঠিকানাটি সঠিক নয়।'
              : 'The email address is not valid.';
          break;
        case 'too-many-requests':
          message = bn
              ? 'অনেকবার চেষ্টা করেছেন। কিছুক্ষণ পরে চেষ্টা করুন।'
              : 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = bn
              ? 'ইন্টারনেট সংযোগ পরীক্ষা করুন।'
              : 'Please check your internet connection.';
          break;
        default:
          message = bn
              ? 'ইমেইল পাঠানো যায়নি। আবার চেষ্টা করুন।'
              : 'Could not send email. Please try again.';
      }

      _showMessage(message);
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        bn
            ? 'একটি সমস্যা হয়েছে। আবার চেষ্টা করুন।'
            : 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  void _startCooldown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (resendCooldown > 0) {
        setState(() => resendCooldown--);
        _startCooldown();
      }
    });
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: deepMaroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
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
        iconTheme: const IconThemeData(color: deepMaroon),
        title: Text(
          bn ? 'পাসওয়ার্ড রিসেট' : 'Reset Password',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: mainText,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: emailSent ? _buildSuccessState(bn) : _buildFormState(bn),
      ),
    );
  }

  // ============================================================
  // FORM STATE
  // ============================================================

  Widget _buildFormState(bool bn) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Lock icon
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: lightMaroon,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryMaroon.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 56,
              color: primaryMaroon,
            ),
          ),

          const SizedBox(height: 28),

          Text(
            bn ? 'পাসওয়ার্ড ভুলে গেছেন?' : 'Forgot Password?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: bn ? 23 : 25,
              fontWeight: FontWeight.w800,
              color: mainText,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            bn
                ? 'আপনার registered ইমেইল দিন।\nআমরা reset link পাঠাবো।'
                : 'Enter your registered email.\nWe\'ll send you a reset link.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: secondaryText,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !isSending,
            decoration: InputDecoration(
              labelText: bn ? 'ইমেইল' : 'Email',
              hintText: 'you@example.com',
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide:
                    const BorderSide(color: primaryMaroon, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return bn
                    ? 'ইমেইল লিখুন'
                    : 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return bn
                    ? 'সঠিক ইমেইল লিখুন'
                    : 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: 28),

          // Send button
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
                onPressed: isSending ? null : _sendResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            bn ? 'Reset Link পাঠান' : 'Send Reset Link',
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

          const SizedBox(height: 20),

          // Back to login
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              size: 16,
              color: secondaryText,
            ),
            label: Text(
              bn ? 'লগইনে ফিরে যান' : 'Back to Login',
              style: const TextStyle(
                color: secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUCCESS STATE
  // ============================================================

  Widget _buildSuccessState(bool bn) {
    return Column(
      children: [
        const SizedBox(height: 30),

        // Checkmark icon
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 56,
            color: Colors.green,
          ),
        ),

        const SizedBox(height: 28),

        Text(
          bn ? '📩 ইমেইল পাঠানো হয়েছে' : '📩 Email Sent',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: bn ? 22 : 24,
            fontWeight: FontWeight.w800,
            color: mainText,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          bn
              ? 'আমরা একটি password reset link পাঠিয়েছি।'
              : 'We\'ve sent a password reset link.',
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              const Icon(Icons.email_outlined,
                  color: primaryMaroon, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  emailController.text.trim(),
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

        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: lightGold,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryGold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: deepGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bn
                      ? 'Inbox এ না পেলে Spam / Promotions folder চেক করুন। Link ২৪ ঘণ্টা পর্যন্ত valid।'
                      : 'If not in inbox, check Spam / Promotions. Link valid for 24 hours.',
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

        const SizedBox(height: 30),

        // Resend button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: (isSending || resendCooldown > 0)
                ? null
                : _sendResetEmail,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(primaryMaroon),
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(
              resendCooldown > 0
                  ? (bn
                      ? 'আবার পাঠান ($resendCooldown সেকেন্ড)'
                      : 'Resend in $resendCooldown s')
                  : (bn ? 'আবার পাঠান' : 'Resend Email'),
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

        const SizedBox(height: 14),

        // Change email button
        TextButton(
          onPressed: () {
            setState(() {
              emailSent = false;
              resendCooldown = 0;
            });
          },
          child: Text(
            bn ? 'অন্য ইমেইল দিয়ে চেষ্টা করুন' : 'Try a different email',
            style: const TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}