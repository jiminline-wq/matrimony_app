import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StreakCard extends StatelessWidget {
  final int streak;
  final bool isBangla;

  const StreakCard({
    super.key,
    required this.streak,
    required this.isBangla,
  });

  @override
  Widget build(BuildContext context) {
    final bn = isBangla;
    // সর্বোচ্চ ৭ দিনের জন্য প্রোগ্রেস (0.0 থেকে 1.0)
    final double progress = (streak / 7).clamp(0.0, 1.0);
    final int daysLeft = 7 - streak;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B1A3A), Color(0xFFD46A2B)], // Maroon to Orange
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Fire Icon + Streak Text
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orangeAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bn
                          ? '$streak দিনের লগইন স্ট্রিক'
                          : '$streak Day Login Streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streak >= 7
                          ? (bn
                              ? '🎉 অভিনন্দন! আপনি ফ্রি বুস্ট পেয়েছেন!'
                              : '🎉 Congrats! You got a Free Boost!')
                          : (bn
                              ? '৭ দিন পূরণ করলে ২৪ ঘণ্টার ফ্রি বুস্ট পাবেন'
                              : 'Complete 7 days for a 24h Free Boost'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$streak/7',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Bottom text: Days left
          if (streak < 7) ...[
            const SizedBox(height: 8),
            Text(
              bn
                  ? 'আরও $daysLeft দিন লগইন করুন বুস্ট পেতে!'
                  : 'Login for $daysLeft more days to get the boost!',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
