import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/like_service.dart';
import '../ads/rewarded_ad_manager.dart';

// ✅ Deferred Loading Import for UserProfileViewScreen
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

class WhoLikedMeScreen extends StatefulWidget {
  final bool isBangla;

  const WhoLikedMeScreen({super.key, required this.isBangla});

  @override
  State<WhoLikedMeScreen> createState() => _WhoLikedMeScreenState();
}

class _WhoLikedMeScreenState extends State<WhoLikedMeScreen> {
  List<Map<String, dynamic>> likers = [];
  Set<String> myLikedUids = {};
  bool isLoading = true;

  bool _isUnlocked = false;
  bool _isUnlocking = false;
  Timestamp? _unlockedUntil;

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
      await loadLikers();
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .get();
      final data = userDoc.data() ?? {};
      final until = data['whoLikedMeUnlockedUntil'] as Timestamp?;

      bool isUnlocked = false;
      if (until != null && until.toDate().isAfter(DateTime.now())) {
        isUnlocked = true;
      }

      setState(() {
        _isUnlocked = isUnlocked;
        _unlockedUntil = until;
      });

      if (isUnlocked) {
        await loadLikers();
      } else {
        setState(() => isLoading = false);
        final rawLikers = await LikeService.getWhoLikedMe(me.uid);
        setState(() => likers = rawLikers);

        // ✅ মোবাইলে পেজে ঢোকার সাথে সাথেই অটোমেটিক অ্যাড শো করবে
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isUnlocked && !_isUnlocking) {
            _unlockWithAd();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Check unlock error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> loadLikers() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final rawLikers = await LikeService.getWhoLikedMe(me.uid);
      final myLikesSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .doc(me.uid)
          .collection('liked')
          .get();

      final myLikes = myLikesSnapshot.docs.map((d) => d.id).toSet();

      final List<Map<String, dynamic>> loaded = [];
      for (final item in rawLikers) {
        final profileData = item['profile'] as Map<String, dynamic>?;
        if (profileData == null) continue;
        final resolvedUid =
            (item['uid'] ?? profileData['uid'] ?? '').toString().trim();
        if (resolvedUid.isEmpty) continue;

        loaded.add({
          'profile': UserProfile.fromMap(profileData, docId: resolvedUid),
          'likedAt': item['likedAt'],
          'isMutual': myLikes.contains(resolvedUid),
        });
      }

      setState(() {
        likers = loaded;
        myLikedUids = myLikes;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [WhoLikedMe] loadLikers failed: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _unlockWithAd() async {
    if (_isUnlocking || kIsWeb) return;
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
            'whoLikedMeUnlockedUntil': Timestamp.fromDate(unlockUntil),
          });

          setState(() {
            _isUnlocked = true;
            _unlockedUntil = Timestamp.fromDate(unlockUntil);
            isLoading = true;
          });

          await loadLikers();
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
              backgroundColor: Colors.redAccent,
            ),
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
        title: Text(
          bn ? 'যারা Like করেছে' : 'Who Liked Me',
          style:
              const TextStyle(color: deepMaroon, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

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

          if (likers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_outline,
                        size: 60, color: primaryMaroon),
                    const SizedBox(height: 24),
                    Text(
                      bn ? 'এখনো কেউ Like করেনি' : 'No likes yet',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: mainText),
                    ),
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
                      child:
                          const Icon(Icons.lock, size: 70, color: primaryGold),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      bn
                          ? '${likers.length} জন আপনাকে Like করেছে!'
                          : '${likers.length} people liked you!',
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
                        label: Text(
                          bn ? '🎬 আবার অ্যাড দেখুন' : '🎬 Watch Ad Again',
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

          // ✅ ডেটা লোড হলে মোবাইল বা ওয়েব লেআউট দেখাবে
          return isDesktop ? _buildWebLayout(bn) : _buildMobileLayout(bn);
        },
      ),
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return RefreshIndicator(
      onRefresh: loadLikers,
      color: primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: likers.length,
        itemBuilder: (context, index) {
          final item = likers[index];
          final profile = item['profile'] as UserProfile;
          final isMutual = item['isMutual'] as bool;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color:
                      isMutual ? Colors.green.shade300 : Colors.grey.shade200,
                  width: isMutual ? 2 : 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(profile, bn),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightMaroon,
                            border: Border.all(color: primaryGold, width: 2)),
                        child: ClipOval(
                          child: profile.photoUrl.isNotEmpty
                              ? AppNetworkImage(profile.photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 35,
                                      color: primaryMaroon))
                              : const Icon(Icons.person,
                                  size: 35, color: primaryMaroon),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      profile.name.isEmpty
                                          ? 'নাম নেই'
                                          : profile.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              if (isMutual)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: Colors.green.shade600,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Text('Matched',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${profile.age} • ${profile.district}',
                              style: const TextStyle(
                                  fontSize: 12, color: secondaryText)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openProfile(profile, bn),
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: Text(bn ? 'প্রোফাইল' : 'Profile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!isMutual)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {},
                          icon: const Icon(Icons.favorite, size: 16),
                          label: Text(bn ? 'Like Back' : 'Like Back'),
                        ),
                      ),
                  ],
                ),
              ],
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
                        color: Colors.pink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.favorite,
                        color: Colors.pink, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn ? 'যারা আপনাকে Like করেছে' : 'Who Liked You',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bn
                            ? 'মোট ${likers.length} জন'
                            : '${likers.length} people in total',
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
                itemCount: likers.length,
                itemBuilder: (context, index) {
                  final item = likers[index];
                  final profile = item['profile'] as UserProfile;
                  final isMutual = item['isMutual'] as bool;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isMutual
                          ? Border.all(color: Colors.green.shade400, width: 2)
                          : null,
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
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                child: profile.photoUrl.isNotEmpty
                                    ? AppNetworkImage(profile.photoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _imgPlaceholder())
                                    : _imgPlaceholder(),
                              ),
                              // ম্যাচড ব্যাজ
                              if (isMutual)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.green.shade600,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Text('Matched',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _openProfile(profile, bn),
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
                                        child: Text(bn ? 'প্রোফাইল' : 'Profile',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    if (!isMutual) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {},
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.pink.shade50,
                                            foregroundColor: Colors.pink,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                          ),
                                          child: Text(bn ? 'Like Back' : 'Like',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ],
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
