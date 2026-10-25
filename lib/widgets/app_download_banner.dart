import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class AppDownloadBanner extends StatelessWidget {
  const AppDownloadBanner({super.key});

  // 📌 এখানে আপনার অ্যাপের আসল লিংক বসাবেন
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

    return Container(
      margin: const EdgeInsets.all(20), // চারপাশে সুন্দর মার্জিন
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: primaryGold.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.download_for_offline_outlined,
                  color: primaryMaroon, size: 22),
              const SizedBox(width: 8),
              Text(
                'ডাউনলোড করুন',
                style: TextStyle(
                  color: primaryMaroon,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'ফাস্ট ও স্মুথ এক্সপেরিয়েন্সের জন্য অ্যাপটি ডাউনলোড করুন।',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  icon: Icons.android,
                  label: 'Android',
                  onTap: () => _launchUrl(playStoreUrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildButton(
                  icon: Icons.apple,
                  label: 'iOS',
                  onTap: () => _launchUrl(appStoreUrl),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF5E8), // হালকা গোল্ড ব্যাকগ্রাউন্ড
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryGold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryMaroon, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: primaryMaroon,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
