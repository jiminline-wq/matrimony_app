import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class AppDownloadBanner extends StatelessWidget {
  const AppDownloadBanner({super.key});

  final String playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.example.matrimony_app";
  final String appStoreUrl = "https://apps.apple.com/app/idYOUR_APP_ID";

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Column(
      children: [
        const Text(
          'অ্যাপটি ডাউনলোড করুন',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google Play Store Button
            _buildStoreButton(
              onTap: () => _launchUrl(playStoreUrl),
              icon: Icons.play_arrow_rounded, // Play Store-এর ত্রিভুজাকার লোগো
              iconColor: const Color(0xFF00D2FF),
              topText: 'GET IT ON',
              bottomText: 'Google Play',
            ),
            const SizedBox(width: 15),
            // Apple App Store Button
            _buildStoreButton(
              onTap: () => _launchUrl(appStoreUrl),
              icon: Icons.apple, // Apple লোগো
              iconColor: Colors.white,
              topText: 'Download on the',
              bottomText: 'App Store',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStoreButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required String topText,
    required String bottomText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black, // অফিশিয়াল স্টোরের মতো কালো ব্যাকগ্রাউন্ড
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  topText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  bottomText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
