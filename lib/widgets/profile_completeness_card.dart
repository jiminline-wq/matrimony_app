import 'package:flutter/material.dart';

import '../services/profile_completeness_service.dart';
import '../theme/colors.dart';

// ============================================================
// PROFILE COMPLETENESS CARD — Compact Maroon + Golden Theme
// (Reduced Height, Similar to Home Banner)
// ============================================================

class ProfileCompletenessCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool isBangla;
  final VoidCallback onEditTap;
  final int maxPendingShown;

  const ProfileCompletenessCard({
    super.key,
    required this.profile,
    required this.isBangla,
    required this.onEditTap,
    this.maxPendingShown = 3,
  });

  @override
  Widget build(BuildContext context) {
    final result = ProfileCompletenessService.calculate(profile);
    final bn = isBangla;

    // Already 100% — hide
    if (result.isComplete) return const SizedBox.shrink();

    final message = bn
        ? ProfileCompletenessService.getMessageBn(result.percent)
        : ProfileCompletenessService.getMessageEn(result.percent);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B1E3F), // Deep Maroon
            Color(0xFF5E1128), // Darker Maroon
            Color(0xFF3A0B1A), // Deepest
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGold.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative gold accent (top-right circle)
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryGold.withValues(alpha: 0.2),
                    primaryGold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(12), // Reduced from 16 to 12
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Important for reducing height
              children: [
                // ============================================================
                // HEADER — Icon + Title + % Badge
                // ============================================================
                Row(
                  children: [
                    // Golden icon circle
                    Container(
                      padding: const EdgeInsets.all(6), // Reduced from 9 to 6
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [primaryGold, Color(0xFFE6A500)],
                        ),
                      ),
                      child: Icon(
                        result.isHigh
                            ? Icons.verified_user
                            : Icons.person_add_alt_1,
                        color: Colors.white,
                        size: 16, // Reduced from 18 to 16
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title + message
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bn
                                ? 'প্রোফাইল ${result.percent}% সম্পূর্ণ'
                                : 'Profile ${result.percent}% complete',
                            style: const TextStyle(
                              fontSize: 13, // Reduced from 14
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 10, // Reduced from 11
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Golden % badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, // Reduced
                        vertical: 4, // Reduced
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryGold, Color(0xFFE6A500)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${result.percent}%',
                        style: const TextStyle(
                          color: Color(0xFF5E1128),
                          fontSize: 12, // Reduced from 14
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10), // Reduced from 14

                // ============================================================
                // PROGRESS BAR
                // ============================================================
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6, // Reduced from 8 to 6
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: result.percent / 100),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  primaryGold,
                                  Color(0xFFFFD966),
                                  primaryGold,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 10), // Reduced from 14

                // ============================================================
                // PENDING ITEMS & BUTTON (Compact Bottom Row)
                // ============================================================
                Row(
                  children: [
                    // Pending items as a single compact text
                    Expanded(
                      child: result.pending.isNotEmpty
                          ? Text(
                              bn
                                  ? '📝 ${result.pending.first.bnLabel}${result.pending.length > 1 ? ' (+${result.pending.length - 1})' : ''}'
                                  : '📝 ${result.pending.first.enLabel}${result.pending.length > 1 ? ' (+${result.pending.length - 1})' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: primaryGold.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),

                    // Compact CTA Button
                    SizedBox(
                      height: 34, // Reduced from 44
                      child: ElevatedButton(
                        onPressed: onEditTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryGold, Color(0xFFE6A500)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit,
                                  size: 14, // Reduced from 16
                                  color: Color(0xFF5E1128),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  bn ? 'সম্পূর্ণ করুন' : 'Complete',
                                  style: const TextStyle(
                                    fontSize: 12, // Reduced from 13
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5E1128),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
