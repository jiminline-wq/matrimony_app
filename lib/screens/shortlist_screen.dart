import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/shortlist_service.dart';
import '../widgets/verified_badge.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../ads/rewarded_ad_manager.dart';

// ✅ Deferred Loading Import for UserProfileViewScreen
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

class ShortlistScreen extends StatefulWidget {
  final bool isBangla;

  const ShortlistScreen({super.key, required this.isBangla});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  List<UserProfile> savedProfiles = [];
  bool isLoading = true;

  // ✅ অ্যাড আনলক স্টেট (পেজে ঢোকার জন্য)
  bool _isUnlocked = false;
  bool _isUnlocking = false;

  // ✅ রিওয়ার্ডেড অ্যাড লিমিট স্টেট (১০ সোয়াইপের জন্য)
  int _swipedCount = 0;
  int _currentLimit = 10;
  bool _isAdLoading = false;

  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    loadSaved();

    if (kIsWeb) {
      _isUnlocked = true;
    } else {
      _showAdOnEnter();
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // ✅ পেজে ঢোকার সাথে সাথে অ্যাড দেখানোর লজিক
  Future<void> _showAdOnEnter() async {
    if (_isUnlocking || kIsWeb) return;
    setState(() => _isUnlocking = true);

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final success = await RewardedAdManager.showAd(onUserEarnedReward: () {});
      if (success) {
        setState(() => _isUnlocked = true);
      }
    } catch (e) {
      debugPrint('❌ Ad show error: $e');
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
  }

  // ✅ ডিফার্ড লোডিং নেভিগেশন
  Future<void> _openProfile(UserProfile profile, bool bn) async {
    if (_isAdLoading) return;

    // ১০ সোয়াইপ লিমিট চেক
    if (_swipedCount >= _currentLimit) {
      _showAdPrompt();
      return;
    }
    setState(() => _swipedCount++);

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

  Future<void> loadSaved() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(me.uid)
          .collection('saved')
          .orderBy('savedAt', descending: true)
          .get();

      final List<UserProfile> loaded = [];

      for (final doc in snapshot.docs) {
        final uid = doc.data()['savedUid'] as String? ?? '';
        if (uid.isEmpty) continue;

        final profileDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (profileDoc.exists) {
          loaded.add(
              UserProfile.fromMap(profileDoc.data()!, docId: profileDoc.id));
        }
      }

      setState(() {
        savedProfiles = loaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // ✅ প্যারামিটারের নাম 'askConfirmation' করা হয়েছে যাতে showDialog() ফাংশনের সাথে কনফ্লিক্ট না হয়
  Future<void> _removeFromShortlist(UserProfile profile,
      {bool askConfirmation = true}) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final bn = widget.isBangla;

    if (askConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(bn ? 'সরিয়ে ফেলবেন?' : 'Remove?'),
          content: Text(bn
              ? '${profile.name}-কে সরিয়ে ফেলবেন?'
              : 'Remove ${profile.name}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(bn ? 'বাতিল' : 'Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(bn ? 'সরান' : 'Remove',
                    style: const TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    // UI থেকে সরিয়ে দেওয়া যাতে সাথে সাথে আপডেট দেখা যায়
    setState(() {
      savedProfiles.removeWhere((p) => p.uid == profile.uid);
    });

    final success =
        await ShortlistService.removeUser(myUid: me.uid, theirUid: profile.uid);

    if (!success && mounted) {
      // যদি ডেটাবেসে ডিলিট ফেইল করে, তবে আবার লোড করে দেখানো
      loadSaved();
    }
  }

  // ============================================================
  // ✅ ১০ সোয়াইপ পর অ্যাড প্রম্পট ডায়ালগ
  // ============================================================
  Future<void> _showAdPrompt() async {
    if (_isAdLoading) return;
    _isAdLoading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: primaryGold, size: 28),
            const SizedBox(width: 8),
            Text(widget.isBangla ? 'লিমিট শেষ!' : 'Limit Reached!',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          widget.isBangla
              ? 'আপনি $_currentLimit টি প্রোফাইল দেখেছেন। আরও ১০টি প্রোফাইল দেখতে একটি ছোট বিজ্ঞাপন দেখুন।'
              : 'You have viewed $_currentLimit profiles. Watch a short ad to see 10 more profiles.',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isAdLoading = false;
            },
            child: Text(widget.isBangla ? 'বাতিল' : 'Cancel',
                style: const TextStyle(color: secondaryText)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              if (kIsWeb) {
                setState(() => _currentLimit += 10);
                _isAdLoading = false;
                return;
              }

              final success =
                  await RewardedAdManager.showAd(onUserEarnedReward: () {});

              if (success) {
                setState(() => _currentLimit += 10);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.isBangla
                          ? '✅ আরও ১০টি প্রোফাইল আনলক হয়েছে!'
                          : '✅ 10 more profiles unlocked!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.isBangla
                          ? 'বিজ্ঞাপনটি শেষ পর্যন্ত দেখতে হবে!'
                          : 'You must watch the full ad!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
              _isAdLoading = false;
            },
            icon: const Icon(Icons.play_circle_fill),
            label: Text(widget.isBangla ? 'অ্যাড দেখুন' : 'Watch Ad'),
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
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
        title: Text(bn ? 'সংরক্ষিত প্রোফাইল' : 'Saved Profiles',
            style: const TextStyle(
                color: deepMaroon, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: deepMaroon),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildBody(bn, constraints.maxWidth > 800);
              },
            ),
          ),
          if (_isUnlocked && !kIsWeb)
            const SafeArea(
              top: false,
              child: BannerAdWidget(placementId: AdConfig.placementSaved),
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
              Text(bn ? 'অ্যাড লোড হচ্ছে...' : 'Loading ad...',
                  style: const TextStyle(color: secondaryText)),
            ]
          ],
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
              const Icon(Icons.lock, size: 80, color: primaryGold),
              const SizedBox(height: 20),
              Text(
                bn ? 'প্রোফাইলগুলো লক করা আছে' : 'Profiles are locked',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon),
              ),
              const SizedBox(height: 10),
              Text(
                bn
                    ? 'আপনার সেভ করা প্রোফাইলগুলো দেখতে একটি ছোট বিজ্ঞাপন দেখুন।'
                    : 'Watch a short ad to view your saved profiles.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: secondaryText),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAdOnEnter,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(
                      bn ? '🎬 অ্যাড দেখে আনলক করুন' : '🎬 Watch Ad to Unlock',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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

    if (savedProfiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmark_border, size: 60, color: primaryMaroon),
              const SizedBox(height: 24),
              Text(
                  bn
                      ? 'এখনো কোনো profile save করেননি'
                      : 'No saved profiles yet',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // ✅ কার্ড সোয়াইপ লেআউট
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: kIsWeb ? 450 : double.infinity,
          maxHeight: kIsWeb ? 600 : double.infinity,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Expanded(
                child: CardSwiper(
                  controller: _swiperController,
                  cardsCount: savedProfiles.length,
                  numberOfCardsDisplayed:
                      savedProfiles.length < 2 ? savedProfiles.length : 2,
                  backCardOffset: const Offset(0, 30),
                  padding: const EdgeInsets.all(8),
                  onSwipe: (previousIndex, currentIndex, direction) {
                    if (_isAdLoading) return false;
                    if (_swipedCount >= _currentLimit) {
                      _showAdPrompt();
                      return false;
                    }

                    final swipedUser = savedProfiles[previousIndex];

                    // ডানে সোয়াইপ = প্রোফাইল দেখতে যাবে
                    // বামে সোয়াইপ = শর্টলিস্ট থেকে রিমুভ হবে
                    if (direction == CardSwiperDirection.right) {
                      _openProfile(swipedUser, bn);
                    } else if (direction == CardSwiperDirection.left) {
                      // কনফার্মেশন ছাড়াই রিমুভ করে দিচ্ছি যাতে সোয়াইপ স্মুথ লাগে
                      _removeFromShortlist(swipedUser, askConfirmation: false);
                    }

                    setState(() {
                      _swipedCount++;
                    });

                    return true;
                  },
                  cardBuilder: (context, index, horizontalOffsetPercentage,
                      verticalOffsetPercentage) {
                    return _buildSwipeCard(savedProfiles[index], bn);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: Colors.redAccent,
                    onTap: () {
                      if (_isAdLoading) return;
                      if (_swipedCount >= _currentLimit) {
                        _showAdPrompt();
                        return;
                      }
                      _swiperController.swipe(CardSwiperDirection.left);
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.visibility,
                    color: primaryMaroon,
                    onTap: () {
                      if (_isAdLoading) return;
                      if (_swipedCount >= _currentLimit) {
                        _showAdPrompt();
                        return;
                      }
                      _swiperController.swipe(CardSwiperDirection.right);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SWIPE CARD
  // ============================================================
  Widget _buildSwipeCard(UserProfile user, bool bn) {
    return GestureDetector(
      onTap: () => _openProfile(user, bn),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: user.photoUrls.isNotEmpty
                    ? _SwipeCardPhotoGallery(photoUrls: user.photoUrls)
                    : Container(
                        color: lightMaroon,
                        child: const Center(
                            child: Icon(Icons.person,
                                size: 100, color: primaryMaroon)),
                      ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85)
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // Saved Badge
              Positioned(
                top: 12,
                left: 12,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryMaroon.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark, color: Colors.white, size: 13),
                        SizedBox(width: 3),
                        Text('Saved',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(bn ? 'দেখতে ট্যাপ' : 'Tap to view',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.name.isEmpty
                                        ? (bn ? 'নাম নেই' : 'No name')
                                        : user.name,
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 8),
                                  const VerifiedBadge(size: 22),
                                ],
                              ],
                            ),
                          ),
                          if (user.age.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(user.age,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              user.district.isEmpty ? '—' : user.district,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

// ============================================================
// SWIPE CARD PHOTO GALLERY
// ============================================================
class _SwipeCardPhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  const _SwipeCardPhotoGallery({required this.photoUrls});

  @override
  State<_SwipeCardPhotoGallery> createState() => _SwipeCardPhotoGalleryState();
}

class _SwipeCardPhotoGalleryState extends State<_SwipeCardPhotoGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppNetworkImage(
          widget.photoUrls[_currentIndex],
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: lightMaroon),
          errorWidget: (_, __, ___) => Container(
            color: lightMaroon,
            child: const Center(
                child: Icon(Icons.person, size: 100, color: primaryMaroon)),
          ),
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: IgnorePointer(
              child: Row(
                children: List.generate(
                  widget.photoUrls.length,
                  (index) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _currentIndex = index),
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
