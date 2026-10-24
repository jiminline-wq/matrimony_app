import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:matrimony_app/widgets/app_network_image.dart';
import '../theme/colors.dart';
import '../services/referral_service.dart';

// ============================================================
// REFERRAL SCREEN
// নিজের code দেখাও + Share + Stats + History
// ============================================================

class ReferralScreen extends StatefulWidget {
  final bool isBangla;

  const ReferralScreen({super.key, required this.isBangla});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String _code = '';
  int _count = 0;
  int _rewards = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    await ReferralService.ensureMyCode();
    final stats = await ReferralService.getMyStats();
    final history = await ReferralService.getMyReferrals();

    if (!mounted) return;
    setState(() {
      _code = stats['code'] ?? '';
      _count = stats['count'] ?? 0;
      _rewards = stats['rewards'] ?? 0;
      _history = history;
      _loading = false;
    });
  }

  // ============================================================
  // COPY CODE
  // ============================================================
  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isBangla ? '✅ Code copy হয়েছে' : '✅ Code copied'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // SHARE
  // ============================================================
  Future<void> _share() async {
    final bn = widget.isBangla;

    final message = bn
        ? '💕 জীবন সাথী matrimony app এ যোগ দিন!\n\n'
            'আমার referral code: $_code\n\n'
            'Code দিয়ে register করলে আপনি পাবেন free boost এবং '
            'আমি পাবো 24-hour boost।\n\n'
            'App: https://jibonsathi.app'
        : '💕 Join Jibon Sathi matrimony app!\n\n'
            'My referral code: $_code\n\n'
            'Use my code when you register and get a boost. '
            'I\'ll get a 24-hour boost too!\n\n'
            'App: https://jibonsathi.app';

    try {
      await Share.share(message, subject: 'Jibon Sathi Referral');
    } catch (e) {
      // Fallback: copy to clipboard
      await _copyCode();
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: deepMaroon),
        title: Text(
          bn ? 'বন্ধু invite করুন' : 'Invite Friends',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryMaroon))
          : RefreshIndicator(
              color: primaryMaroon,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  _buildHeroCard(bn),
                  const SizedBox(height: 20),
                  _buildCodeCard(bn),
                  const SizedBox(height: 16),
                  _buildStatsRow(bn),
                  const SizedBox(height: 20),
                  _buildHowItWorks(bn),
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildHistoryHeader(bn),
                    const SizedBox(height: 10),
                    ..._history.map((h) => _buildHistoryTile(h, bn)),
                  ],
                ],
              ),
            ),
    );
  }

  // -------- Hero --------
  Widget _buildHeroCard(bool bn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryGold, primaryMaroon],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            bn
                ? 'বন্ধু invite করে পেয়ে যান boost! ⚡'
                : 'Invite friends, earn boosts! ⚡',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bn
                ? 'প্রতিটা বন্ধু register করলে আপনি পাবেন 24-hour free boost'
                : 'Get a 24-hour free boost for each friend who joins',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // -------- Code Card --------
  Widget _buildCodeCard(bool bn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            bn ? 'আপনার referral code' : 'Your referral code',
            style: const TextStyle(
              fontSize: 13,
              color: secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          // Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: lightMaroon,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryMaroon.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _code,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryMaroon,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _copyCode,
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: primaryMaroon,
                    size: 22,
                  ),
                  tooltip: bn ? 'কপি' : 'Copy',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Share button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.share_rounded, size: 20),
              label: Text(
                bn ? 'বন্ধুকে share করুন' : 'Share with Friends',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------- Stats --------
  Widget _buildStatsRow(bool bn) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_alt_rounded,
            value: '$_count',
            label: bn ? 'বন্ধু যোগ হয়েছে' : 'Friends Joined',
            color: primaryMaroon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.bolt_rounded,
            value: '$_rewards',
            label: bn ? 'Boost পেয়েছেন' : 'Boosts Earned',
            color: primaryGold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // -------- How it works --------
  Widget _buildHowItWorks(bool bn) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGold,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: deepGold, size: 20),
              const SizedBox(width: 8),
              Text(
                bn ? 'কীভাবে কাজ করে' : 'How it works',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(
            '1',
            bn
                ? 'আপনার code বন্ধুকে share করুন'
                : 'Share your code with a friend',
          ),
          _buildStep(
            '2',
            bn
                ? 'বন্ধু register করার সময় code দেবে'
                : 'Friend enters code while registering',
          ),
          _buildStep(
            '3',
            bn
                ? 'আপনি পাবেন 24-hour free boost ⚡'
                : 'You get a 24-hour free boost ⚡',
          ),
          _buildStep(
            '4',
            bn ? 'বেশি বন্ধু মানে বেশি boost!' : 'More friends = more boosts!',
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: primaryMaroon,
            ),
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: mainText,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------- History --------
  Widget _buildHistoryHeader(bool bn) {
    return Row(
      children: [
        const Icon(Icons.history_rounded, size: 20, color: primaryMaroon),
        const SizedBox(width: 8),
        Text(
          bn ? 'Recent Invites' : 'Recent Invites',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: mainText,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item, bool bn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: lightMaroon,
            backgroundImage: (item['photoUrl'] as String).isNotEmpty
                ? CachedNetworkImageProvider(item['photoUrl'])
                : null,
            child: (item['photoUrl'] as String).isEmpty
                ? const Icon(Icons.person, color: primaryMaroon, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['name'] ?? 'User',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mainText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lightGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 12, color: deepGold),
                SizedBox(width: 3),
                Text(
                  '+24h',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: deepGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
