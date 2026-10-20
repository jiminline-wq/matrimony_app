import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import 'user_profile_view_screen.dart';
import '../models/user_profile.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../ads/rewarded_ad_manager.dart'; // ✅ রিওয়ার্ডেড অ্যাড ইমপোর্ট

class WhoViewedMeScreen extends StatefulWidget {
  final bool isBangla;

  const WhoViewedMeScreen({super.key, required this.isBangla});

  @override
  State<WhoViewedMeScreen> createState() => _WhoViewedMeScreenState();
}

class _WhoViewedMeScreenState extends State<WhoViewedMeScreen> {
  List<Map<String, dynamic>> viewers = [];
  bool isLoading = true;

  // ✅ আনলক স্ট্যাটাস
  bool _isUnlocked = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _checkUnlockStatusAndLoad();
  }

  Future<void> _checkUnlockStatusAndLoad() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final data = userDoc.data() ?? {};
      final until = data['whoViewedMeUnlockedUntil'] as Timestamp?;

      bool isUnlocked = false;
      if (until != null && until.toDate().isAfter(DateTime.now())) {
        isUnlocked = true;
      }

      setState(() => _isUnlocked = isUnlocked);

      if (isUnlocked) {
        await loadViewers();
      } else {
        setState(() => isLoading = false);
        // লক থাকলেও ভিউয়ার সংখ্যা দেখানোর জন্য ডেটা আনি
        final snap = await FirebaseFirestore.instance
            .collection('profileViews')
            .doc(me.uid)
            .collection('viewers')
            .get();
        setState(() {
          viewers = List.generate(snap.docs.length, (i) => {'dummy': true});
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> loadViewers() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('profileViews')
          .doc(me.uid)
          .collection('viewers')
          .orderBy('viewedAt', descending: true)
          .limit(100)
          .get();

      final List<Map<String, dynamic>> loaded = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final viewerUid = data['viewerUid'] as String? ?? '';
        if (viewerUid.isEmpty) continue;

        try {
          final profileDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(viewerUid)
              .get();
          if (profileDoc.exists) {
            loaded.add({
              'viewerUid': viewerUid,
              'profile': UserProfile.fromMap(profileDoc.data()!, docId: doc.id),
              'viewedAt': data['viewedAt'],
            });
          }
        } catch (e) {}
      }

      setState(() {
        viewers = loaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _unlockWithAd() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    try {
      final success = await RewardedAdManager.showAd(
        onUserEarnedReward: () {},
      );

      if (success) {
        final me = FirebaseAuth.instance.currentUser;
        if (me != null) {
          final unlockUntil = DateTime.now().add(const Duration(hours: 24));
          await FirebaseFirestore.instance
              .collection('users')
              .doc(me.uid)
              .update({
            'whoViewedMeUnlockedUntil': Timestamp.fromDate(unlockUntil),
          });

          setState(() {
            _isUnlocked = true;
            isLoading = true;
          });

          await loadViewers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(widget.isBangla
                      ? '✅ ২৪ ঘণ্টার জন্য আনলক হয়েছে!'
                      : '✅ Unlocked for 24 hours!'),
                  backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Unlock failed: $e');
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(
          bn ? 'আমার প্রোফাইল দেখেছে' : 'Profile Viewers',
          style:
              const TextStyle(color: deepMaroon, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(bn)),
          if (_isUnlocked) // ✅ আনলকড হলে অ্যাড দেখাবে
            const BannerAdWidget(placementId: AdConfig.placementWhoViewed),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
    }

    if (viewers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 60, color: primaryMaroon),
              const SizedBox(height: 24),
              Text(
                bn ? 'এখনো কেউ আপনার profile দেখেনি' : 'No profile views yet',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ লকড স্ক্রিন
    if (!_isUnlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryGold.withValues(alpha: 0.2)),
                child: const Icon(Icons.visibility_off,
                    size: 70, color: primaryGold),
              ),
              const SizedBox(height: 24),
              Text(
                bn
                    ? '${viewers.length} জন আপনার প্রোফাইল দেখেছেন!'
                    : '${viewers.length} people viewed your profile!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon),
              ),
              const SizedBox(height: 10),
              Text(
                bn
                    ? 'কে কে দেখেছেন তা জানতে একটি ছোট বিজ্ঞাপন দেখুন।'
                    : 'Watch a short ad to see who viewed you.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: secondaryText, height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUnlocking ? null : _unlockWithAd,
                  icon: _isUnlocking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_circle_fill),
                  label: Text(
                    _isUnlocking
                        ? (bn ? 'অ্যাড চলছে...' : 'Ad playing...')
                        : (bn
                            ? '🎬 অ্যাড দেখে আনলক করুন'
                            : '🎬 Watch Ad to Unlock'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ আনলকড লিস্ট
    return RefreshIndicator(
      onRefresh: loadViewers,
      color: primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: viewers.length,
        itemBuilder: (context, index) {
          final item = viewers[index];
          final profile = item['profile'] as UserProfile;
          final viewedAt = item['viewedAt'];

          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UserProfileViewScreen(isBangla: bn, user: profile))),
            child: Container(
              // ... (এখানে আপনার আগের ভিউয়ার কার্ডের ডিজাইন হুবহু বসবে)
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: lightMaroon),
                    child: ClipOval(
                      child: profile.photoUrl.isNotEmpty
                          ? Image.network(profile.photoUrl, fit: BoxFit.cover)
                          : const Icon(Icons.person, color: primaryMaroon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${profile.age} • ${profile.district}',
                            style: const TextStyle(
                                fontSize: 12, color: secondaryText)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: secondaryText),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
