import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ads/ad_frequency_service.dart';
import '../ads/rewarded_ad_manager.dart';
import '../theme/colors.dart';
import '../utils/boost_service.dart';

class BoostScreen extends StatefulWidget {
  final bool isBangla;
  const BoostScreen({super.key, required this.isBangla});

  @override
  State<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends State<BoostScreen> {
  bool _isLoading = true;
  bool _isBoosting = false;
  DateTime? _boostedUntil;
  BoostEligibility? _eligibility;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // ✅ Pre-load rewarded ad
    RewardedAdManager.loadAd();
  }

  // ============================================================
  // LOAD CURRENT BOOST STATUS
  // ============================================================
  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = doc.data() ?? {};
      final until = data['boostedUntil'] as Timestamp?;

      final eligibility = await AdFrequencyService.canBoostToday();

      setState(() {
        _boostedUntil = until?.toDate();
        _eligibility = eligibility;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ _loadStatus error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // CHECK IF CURRENTLY BOOSTED
  // ============================================================
  bool get _isCurrentlyBoosted {
    if (_boostedUntil == null) return false;
    return _boostedUntil!.isAfter(DateTime.now());
  }

  String get _remainingTime {
    if (_boostedUntil == null) return '';
    final diff = _boostedUntil!.difference(DateTime.now());
    if (diff.isNegative) return '';

    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '$h ঘন্টা $m মিনিট বাকি';
    return '$m মিনিট বাকি';
  }

  // ============================================================
  // WATCH AD → BOOST
  // ============================================================
  Future<void> _watchAdAndBoost() async {
    if (_isBoosting) return;

    // ✅ Check eligibility
    if (_eligibility != null && !_eligibility!.canBoost) {
      _showSnack(
        widget.isBangla
            ? 'আজকের boost সীমা শেষ। আগামীকাল আবার চেষ্টা করুন।'
            : 'Daily boost limit reached. Try again tomorrow.',
      );
      return;
    }

    setState(() => _isBoosting = true);

    try {
      // ✅ Show rewarded ad
      final rewarded = await RewardedAdManager.showAd(
        onUserEarnedReward: () {
          debugPrint('🎁 [Boost] Reward earned — applying boost');
        },
      );

      if (!rewarded) {
        _showSnack(
          widget.isBangla
              ? 'Ad পুরো দেখতে হবে। আবার চেষ্টা করুন।'
              : 'Watch the full ad to boost. Try again.',
        );
        setState(() => _isBoosting = false);
        return;
      }

      // ✅ Apply boost (12h)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isBoosting = false);
        return;
      }

      final success = await BoostService.boostFor12Hours(uid);

      if (!success) {
        _showSnack(
          widget.isBangla
              ? 'Boost করা যায়নি। আবার চেষ্টা করুন।'
              : 'Could not boost. Try again.',
        );
        setState(() => _isBoosting = false);
        return;
      }

      // ✅ Record usage
      await AdFrequencyService.recordBoostUsage();

      _showSnack(
        widget.isBangla
            ? '✅ সফল! আপনার profile ১২ ঘন্টার জন্য Boosted'
            : '✅ Success! Your profile is boosted for 12 hours',
        isSuccess: true,
      );

      // Reload status
      await _loadStatus();
    } catch (e) {
      debugPrint('❌ _watchAdAndBoost error: $e');
      _showSnack(
        widget.isBangla ? 'কিছু ভুল হয়েছে' : 'Something went wrong',
      );
    } finally {
      if (mounted) setState(() => _isBoosting = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : primaryMaroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: deepMaroon),
        title: Text(
          bn ? 'প্রোফাইল বুস্ট' : 'Boost Profile',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(bn),
                  const SizedBox(height: 24),
                  _buildBenefits(bn),
                  const SizedBox(height: 32),
                  _buildBoostButton(bn),
                  const SizedBox(height: 16),
                  _buildLimitText(bn),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================
  Widget _buildStatusCard(bool bn) {
    final isBoosted = _isCurrentlyBoosted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBoosted
              ? [primaryGold, primaryMaroon]
              : [Colors.grey.shade200, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isBoosted ? primaryMaroon : Colors.grey)
                .withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isBoosted ? Icons.bolt : Icons.bolt_outlined,
            color: isBoosted ? Colors.white : Colors.grey.shade600,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            isBoosted
                ? (bn ? '🚀 Boosted!' : '🚀 Boosted!')
                : (bn ? 'Boosted নয়' : 'Not Boosted'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isBoosted ? Colors.white : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isBoosted
                ? _remainingTime
                : (bn
                    ? 'Boost দিলে আপনার profile সবার আগে দেখা যাবে'
                    : 'Boost to get seen first by others'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isBoosted
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BENEFITS
  // ============================================================
  Widget _buildBenefits(bool bn) {
    final items = [
      {
        'icon': Icons.trending_up,
        'title': bn ? '১০x বেশি views' : '10x more views',
        'desc': bn
            ? 'আপনার profile Discover-এ টপে দেখাবে'
            : 'Your profile appears first in Discover',
      },
      {
        'icon': Icons.favorite,
        'title': bn ? '৩x বেশি likes' : '3x more likes',
        'desc': bn
            ? 'বেশি মানুষ আপনার profile দেখে like করবে'
            : 'More people will see and like your profile',
      },
      {
        'icon': Icons.access_time,
        'title': bn ? '১২ ঘন্টা active' : '12 hours active',
        'desc': bn
            ? 'একটি ad দেখলেই ১২ ঘন্টার boost'
            : 'Watch one ad to get 12 hours of boost',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bn ? 'Boost-এর সুবিধা' : 'Benefits of Boost',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: deepMaroon,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [primaryGold, primaryMaroon],
                    ),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: mainText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['desc'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // BOOST BUTTON
  // ============================================================
  Widget _buildBoostButton(bool bn) {
    final canBoost = _eligibility?.canBoost ?? true;
    final isBoosted = _isCurrentlyBoosted;

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed:
            (_isBoosting || !canBoost || isBoosted) ? null : _watchAdAndBoost,
        icon: _isBoosting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Icon(isBoosted ? Icons.check_circle : Icons.play_circle_fill),
        label: Text(
          _isBoosting
              ? (bn ? 'Ad চলছে...' : 'Ad playing...')
              : isBoosted
                  ? (bn ? '✅ Boosted' : '✅ Boosted')
                  : !canBoost
                      ? (bn ? 'আজকের সীমা শেষ' : 'Daily limit reached')
                      : (bn
                          ? '🎬 Ad দেখে ১২ ঘণ্টা Boost'
                          : '🎬 Watch Ad for 12h Boost'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LIMIT TEXT
  // ============================================================
  Widget _buildLimitText(bool bn) {
    if (_eligibility == null) return const SizedBox.shrink();

    return Center(
      child: Text(
        bn
            ? 'আজ ${_eligibility!.usedToday}/${AdFrequencyService.maxBoostsPerDay} boost ব্যবহৃত'
            : '${_eligibility!.usedToday}/${AdFrequencyService.maxBoostsPerDay} boosts used today',
        style: const TextStyle(
          fontSize: 12,
          color: secondaryText,
        ),
      ),
    );
  }
}
