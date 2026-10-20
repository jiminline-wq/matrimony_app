import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/like_service.dart';
import 'user_profile_view_screen.dart';
import '../ads/rewarded_ad_manager.dart';

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

  // ✅ আনলক স্ট্যাটাস
  bool _isUnlocked = false;
  bool _isUnlocking = false;
  Timestamp? _unlockedUntil;

  @override
  void initState() {
    super.initState();
    // ✅ পেজে ঢোকার সাথে সাথেই অ্যাড লোড করা শুরু করি
    RewardedAdManager.loadAd();
    _checkUnlockStatusAndLoad();
  }

  // ✅ চেক করা ইউজার অ্যাড দেখে আগে আনলক করেছে কি না
  Future<void> _checkUnlockStatusAndLoad() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

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
        // লক থাকলেও কারেন্ট লাইকার সংখ্যা দেখানোর জন্য ডেটা আনি
        final rawLikers = await LikeService.getWhoLikedMe(me.uid);
        setState(() => likers = rawLikers);
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

  // ✅ রিওয়ার্ডেড অ্যাড দেখে আনলক করা
  Future<void> _unlockWithAd() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    try {
      // অ্যাড শো করার চেষ্টা করি
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
        // ✅ যদি অ্যাড লোড না হয় বা ইউজার অ্যাড পুরোটা না দেখে বন্ধ করে দেয়
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isBangla
                  ? 'বিজ্ঞাপনটি সম্পূর্ণ দেখতে হবে। ইন্টারনেট চেক করে আবার চেষ্টা করুন।'
                  : 'You must watch the full ad. Check internet and try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Unlock failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isBangla
                ? 'কিছু ভুল হয়েছে। আবার চেষ্টা করুন।'
                : 'Something went wrong. Try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
      body: _buildBody(bn),
    );
  }

  Widget _buildBody(bool bn) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
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
                    fontSize: 20, fontWeight: FontWeight.bold, color: mainText),
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
                  color: primaryGold.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.lock, size: 70, color: primaryGold),
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
              const SizedBox(height: 10),
              Text(
                bn
                    ? 'কে কে লাইক করেছে তা দেখতে একটি ছোট বিজ্ঞাপন দেখুন।'
                    : 'Watch a short ad to see who liked you.',
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
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => UserProfileViewScreen(
                                  isBangla: bn, user: profile))),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lightMaroon,
                            border: Border.all(color: primaryGold, width: 2)),
                        child: ClipOval(
                          child: profile.photoUrl.isNotEmpty
                              ? Image.network(profile.photoUrl,
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
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => UserProfileViewScreen(
                                    isBangla: bn, user: profile))),
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: Text(bn ? 'প্রোফাইল' : 'Profile'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!isMutual)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // আপনার আগের _likeBack ফাংশন এখানে কল হবে
                          },
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
}
