import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../ads/rewarded_ad_manager.dart';

// ✅ Deferred Loading Import for UserProfileViewScreen
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

class WhoViewedMeScreen extends StatefulWidget {
  final bool isBangla;

  const WhoViewedMeScreen({super.key, required this.isBangla});

  @override
  State<WhoViewedMeScreen> createState() => _WhoViewedMeScreenState();
}

class _WhoViewedMeScreenState extends State<WhoViewedMeScreen> {
  List<Map<String, dynamic>> viewers = [];
  bool isLoading = true;
  bool _isUnlocked = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    // ✅ ওয়েবে অ্যাড লোড করা যাবে না
    if (!kIsWeb) {
      RewardedAdManager.loadAd();
    }
    _checkUnlockStatusAndLoad();
  }

  // ✅ DEFERRED NAVIGATION HELPER FOR PROFILE VIEW
  Future<void> _openProfile(UserProfile profile, bool bn) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await user_profile_view_lib.loadLibrary();

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => user_profile_view_lib.UserProfileViewScreen(
            isBangla: bn,
            user: profile,
          ),
        ),
      );
    }
  }

  Future<void> _checkUnlockStatusAndLoad() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    // ✅ ওয়েবের জন্য সরাসরি আনলক করে দেওয়া হলো (যেহেতু অ্যাড কাজ করবে না)
    if (kIsWeb) {
      setState(() {
        _isUnlocked = true;
        isLoading = true;
      });
      await loadViewers();
      return;
    }

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
        final snap = await FirebaseFirestore.instance
            .collection('profileViews')
            .doc(me.uid)
            .collection('viewers')
            .get();
        setState(() {
          viewers = List.generate(snap.docs.length, (i) => {'dummy': true});
        });

        // ✅ মোবাইলে পেজে ঢোকার সাথে সাথেই অটোমেটিক অ্যাড শো করবে
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isUnlocked && !_isUnlocking) {
            _unlockWithAd();
          }
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
    if (_isUnlocking || kIsWeb) return;
    setState(() => _isUnlocking = true);

    try {
      final success = await RewardedAdManager.showAd(onUserEarnedReward: () {});

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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(widget.isBangla
                    ? 'বিজ্ঞাপনটি সম্পূর্ণ দেখতে হবে। আবার চেষ্টা করুন।'
                    : 'You must watch the full ad. Try again.'),
                backgroundColor: Colors.redAccent),
          );
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
        title: Text(bn ? 'আমার প্রোফাইল দেখেছে' : 'Profile Viewers',
            style: const TextStyle(
                color: deepMaroon, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return _buildBody(bn, isDesktop);
              },
            ),
          ),
          // ✅ AdMob শুধু মোবাইলে
          if (_isUnlocked && !kIsWeb)
            const SafeArea(
              top: false,
              child: BannerAdWidget(placementId: AdConfig.placementWhoViewed),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn, bool isDesktop) {
    if (isLoading || _isUnlocking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: primaryMaroon),
            if (_isUnlocking) ...[
              const SizedBox(height: 16),
              Text(bn ? 'বিজ্ঞাপন লোড হচ্ছে...' : 'Loading ad...',
                  style: const TextStyle(color: secondaryText)),
            ]
          ],
        ),
      );
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

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
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _unlockWithAd,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(bn ? '🎬 আবার অ্যাড দেখুন' : '🎬 Watch Ad Again',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ আনলকড হলে মোবাইল বা ওয়েব লেআউট দেখাবে
    return isDesktop ? _buildWebLayout(bn) : _buildMobileLayout(bn);
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return RefreshIndicator(
      onRefresh: loadViewers,
      color: primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: viewers.length,
        itemBuilder: (context, index) {
          final item = viewers[index];
          final profile = item['profile'] as UserProfile;

          return GestureDetector(
            onTap: () => _openProfile(profile, bn),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: lightMaroon),
                    child: ClipOval(
                      child: profile.photoUrl.isNotEmpty
                          ? AppNetworkImage(profile.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: primaryMaroon))
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

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম গ্রিড ভিউ)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // হেডার
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.visibility,
                        color: Colors.blue, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn ? 'প্রোফাইল ভিউয়ার্স' : 'Profile Viewers',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bn
                            ? 'মোট ${viewers.length} জন আপনার প্রোফাইল দেখেছেন'
                            : '${viewers.length} people viewed your profile',
                        style:
                            const TextStyle(fontSize: 14, color: secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // গ্রিড ভিউ
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  mainAxisExtent: 320, // কার্ডের নির্দিষ্ট উচ্চতা
                ),
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final item = viewers[index];
                  final profile = item['profile'] as UserProfile;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ইমেজ
                        Expanded(
                          flex: 5,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: profile.photoUrl.isNotEmpty
                                ? AppNetworkImage(profile.photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder())
                                : _imgPlaceholder(),
                          ),
                        ),

                        // ইনফো
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.name.isEmpty
                                          ? 'নাম নেই'
                                          : profile.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: mainText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${profile.age} • ${profile.district}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: secondaryText)),
                                  ],
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _openProfile(profile, bn),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryMaroon,
                                      side: BorderSide(
                                          color: primaryMaroon.withValues(
                                              alpha: 0.3)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                    ),
                                    child: Text(
                                        bn ? 'প্রোফাইল দেখুন' : 'View Profile',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: lightMaroon,
      child: const Center(
          child: Icon(Icons.person, size: 80, color: primaryMaroon)),
    );
  }
}
