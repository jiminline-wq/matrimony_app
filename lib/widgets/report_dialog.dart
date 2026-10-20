import 'package:flutter/material.dart';

import '../theme/colors.dart';

// ============================================================
// REPORT DIALOG
// ============================================================

class ReportDialog extends StatefulWidget {
  final bool isBangla;
  final String reportedUserName;

  const ReportDialog({
    super.key,
    required this.isBangla,
    required this.reportedUserName,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  final List<Map<String, String>> reasons = [
    {
      'bn': 'অশ্লীল বা অপ্রাসঙ্গিক ছবি',
      'en': 'Inappropriate photos',
    },
    {
      'bn': 'মিথ্যা বা ভুয়া প্রোফাইল',
      'en': 'Fake profile',
    },
    {
      'bn': 'হয়রানি বা বিরক্ত করা',
      'en': 'Harassment',
    },
    {
      'bn': 'বাজে ভাষা বা আচরণ',
      'en': 'Bad language',
    },
    {
      'bn': 'স্ক্যাম বা প্রতারণা',
      'en': 'Scam or fraud',
    },
    {
      'bn': 'বিয়ে করা সত্ত্বেও প্রোফাইল',
      'en': 'Married but on app',
    },
    {
      'bn': 'অন্যান্য',
      'en': 'Other',
    },
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flag,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bn ? 'রিপোর্ট করুন' : 'Report User',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: mainText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              bn
                  ? '${widget.reportedUserName}-কে কেন রিপোর্ট করছেন?'
                  : 'Why are you reporting ${widget.reportedUserName}?',
              style: const TextStyle(
                fontSize: 13,
                color: secondaryText,
              ),
            ),

            const SizedBox(height: 16),

            // Reasons list
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: reasons.map((reason) {
                    final label = bn ? reason['bn']! : reason['en']!;
                    final isSelected = _selectedReason == reason['en'];

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedReason = reason['en']);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? lightMaroon
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? primaryMaroon
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: isSelected
                                  ? primaryMaroon
                                  : secondaryText,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? primaryMaroon
                                      : mainText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Details
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: bn
                    ? 'অতিরিক্ত তথ্য (ঐচ্ছিক)...'
                    : 'Additional details (optional)...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
                filled: true,
                fillColor: warmWhite,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: secondaryText,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      bn ? 'বাতিল' : 'Cancel',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedReason == null
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'reason': _selectedReason,
                              'details': _detailsController.text.trim(),
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      bn ? 'রিপোর্ট করুন' : 'Report',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}