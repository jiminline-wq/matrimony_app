import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class AppDownloadBanner extends StatelessWidget {
  const AppDownloadBanner({super.key});

  // 📌 এখানে আপনার অ্যাপের আসল লিংক বসাবেন
  final String playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.example.matrimony_app";
  final String appStoreUrl =
      "https://apps.apple.com/app/idYOUR_APP_ID"; // iOS অ্যাপ পাবলিশ হলে এই লিংক দিন

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ শুধুমাত্র ওয়েবসাইটে দেখাবে, মোবাইল অ্যাপে দেখাবে না
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF800020), Color(0xFF4A0012)], // আপনার মেরুন কালার
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // মোবাইলে ওয়েবসাইট দেখলে যাতে ভেঙে না যায়, তাই রেস্পন্সিভ ডিজাইন
          bool isSmallScreen = constraints.maxWidth < 600;

          return Flex(
            direction: isSmallScreen ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isSmallScreen
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              // টেক্সট পার্ট
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'জীবন সাথী অ্যাপ ডাউনলোড করুন',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ফাস্ট ও স্মুথ এক্সপেরিয়েন্সের জন্য অ্যাপটি ডাউনলোড করুন।',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 12 : 0),

              // বাটন পার্ট
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildButton(
                    icon: Icons.android,
                    label: 'Android',
                    onTap: () => _launchUrl(playStoreUrl),
                  ),
                  _buildButton(
                    icon: Icons.apple,
                    label: 'iOS',
                    onTap: () => _launchUrl(appStoreUrl),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF800020), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF800020),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
