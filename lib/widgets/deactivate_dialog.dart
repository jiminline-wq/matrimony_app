import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/deactivate_service.dart';

// ============================================================
// DEACTIVATE DIALOG
// ২টা step: Warning → Password confirm
// Return: true যদি deactivate হয়, null অন্যথায়
// ============================================================

class DeactivateDialog extends StatefulWidget {
  final bool isBangla;

  const DeactivateDialog({super.key, required this.isBangla});

  static Future<bool?> show(BuildContext context, {required bool isBangla}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeactivateDialog(isBangla: isBangla),
    );
  }

  @override
  State<DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<DeactivateDialog> {
  int _step = 1; // 1 = warning, 2 = password

  String? _selectedReason;
  final _feedbackController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isProcessing = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final List<Map<String, String>> _reasons = [
    {'value': 'Found match', 'bn': 'সাথী পেয়ে গেছি', 'en': 'Found my match'},
    {'value': 'Taking a break', 'bn': 'একটু বিরতি নিতে চাই', 'en': 'Taking a break'},
    {'value': 'Privacy concerns', 'bn': 'গোপনীয়তার সমস্যা', 'en': 'Privacy concerns'},
    {'value': 'Not satisfied', 'bn': 'সন্তুষ্ট নই', 'en': 'Not satisfied'},
    {'value': 'Other', 'bn': 'অন্য কারণ', 'en': 'Other'},
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // STEP 1 → 2
  // ============================================================

  void _goToStep2() {
    if (_selectedReason == null) {
      setState(() {
        _errorMessage = widget.isBangla
            ? 'একটা কারণ নির্বাচন করুন'
            : 'Please select a reason';
      });
      return;
    }
    setState(() {
      _step = 2;
      _errorMessage = null;
    });
  }

  // ============================================================
  // CONFIRM — password verify → deactivate
  // ============================================================

  Future<void> _confirmDeactivate() async {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() {
        _errorMessage = widget.isBangla
            ? 'পাসওয়ার্ড দিন'
            : 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // 1. Re-authenticate
    final authResult = await DeactivateService.reauthenticate(password: pwd);
    if (authResult['success'] != true) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = authResult['error']?.toString() ??
            (widget.isBangla
                ? 'Authentication ব্যর্থ হয়েছে'
                : 'Authentication failed');
      });
      return;
    }

    // 2. Deactivate
    final result = await DeactivateService.deactivateAccount(
      reason: _selectedReason ?? 'Other',
      feedback: _feedbackController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isProcessing = false;
        _errorMessage = widget.isBangla
            ? 'Deactivate করা যায়নি। আবার চেষ্টা করুন।'
            : 'Could not deactivate. Please try again.';
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      backgroundColor: warmWhite,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: _step == 1 ? _buildStep1(bn) : _buildStep2(bn),
      ),
    );
  }

  // -------- STEP 1: Warning + Reason --------
  Widget _buildStep1(bool bn) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning icon
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Center(
            child: Text(
              bn ? 'Account Deactivate?' : 'Deactivate Account?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: deepMaroon,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            bn
                ? 'আপনার প্রোফাইল Discover, Nearby এবং Matches থেকে লুকিয়ে যাবে। '
                    'যতক্ষণ reactivate না করবেন, ততক্ষণ কেউ আপনাকে দেখতে পাবে না।'
                : 'Your profile will be hidden from Discover, Nearby and Matches. '
                    'No one can see you until you reactivate.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightGold,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryGold.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: deepGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bn
                        ? 'আপনার সব তথ্য সুরক্ষিত থাকবে। যেকোনো সময় আবার ফিরে আসতে পারবেন।'
                        : 'All your data will be saved. You can come back anytime.',
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
          const SizedBox(height: 18),

          // Reason dropdown
          Text(
            bn ? 'কারণ (ঐচ্ছিক)' : 'Reason (optional)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: mainText,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4DCEA)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                hint: Text(
                  bn ? 'কারণ নির্বাচন করুন' : 'Select a reason',
                  style: const TextStyle(fontSize: 14),
                ),
                items: _reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r['value'],
                    child: Text(bn ? r['bn']! : r['en']!),
                  );
                }).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedReason = v;
                    _errorMessage = null;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Feedback field
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            maxLength: 200,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: bn
                  ? 'আর কিছু বলতে চান? (ঐচ্ছিক)'
                  : 'Anything else? (optional)',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryMaroon, width: 1.5),
              ),
            ),
          ),

          // Error
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: primaryMaroon, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    bn ? 'বাতিল' : 'Cancel',
                    style: const TextStyle(
                      color: primaryMaroon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _goToStep2,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    bn ? 'পরবর্তী' : 'Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------- STEP 2: Password confirm --------
  Widget _buildStep2(bool bn) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.red,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),

          Text(
            bn ? 'নিশ্চিত করুন' : 'Confirm',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepMaroon,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            bn
                ? 'Deactivate করতে আপনার পাসওয়ার্ড দিন'
                : 'Enter your password to deactivate',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              labelText: bn ? 'পাসওয়ার্ড' : 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: primaryMaroon),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: secondaryText,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4DCEA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryMaroon, width: 1.5),
              ),
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _step = 1;
                            _errorMessage = null;
                            _passwordController.clear();
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: primaryMaroon, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    bn ? 'পিছনে' : 'Back',
                    style: const TextStyle(
                      color: primaryMaroon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _confirmDeactivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          bn ? 'Deactivate' : 'Deactivate',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}