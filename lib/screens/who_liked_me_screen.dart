import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/like_service.dart';
import '../utils/block_report_service.dart';
import '../ads/rewarded_ad_manager.dart';
import '../widgets/verified_badge.dart';

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

  // ✅ রিওয়ার্ডেড অ্যাড লিমিট স্টেট
  int _swipedCount = 0;
  int _currentLimit = 10;
  bool _isAdLoading = false;

  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      RewardedAdManager.loadAd();
    }
    _checkUnlockStatusAndLoad();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // ✅ DEFERRED NAVIGATION HELPER FOR PROFILE VIEW
  Future<void> _openProfile(UserProfile profile, bool bn) async {
    if (_isAdLoading) return;

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

  Future<void> _checkUnlockStatusAndLoad() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

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

  // ============================================================
  // LIKE BACK (ডানে সোয়াইপ করলে)
  // ============================================================
  Future<void> _likeBack(UserProfile targetUser) async {
    final myUser = FirebaseAuth.instance.currentUser;
    if (myUser == null) return;
    if (myUser.uid.trim().isEmpty || targetUser.uid.trim().isEmpty) return;

    try {
      await LikeService.likeUser(myUid: myUser.uid, theirUid: targetUser.uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.white),
              const SizedBox(width: 10),
              Text(widget.isBangla
                  ? '${targetUser.name}-কে like করা হয়েছে'
                  : 'Liked ${targetUser.name}'),
            ],
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('❌ likeBack error: $e');
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
          return _buildBody(bn, isDesktop);
        },
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
                  cardsCount: likers.length,
                  numberOfCardsDisplayed: likers.length < 2 ? likers.length : 2,
                  backCardOffset: const Offset(0, 30),
                  padding: const EdgeInsets.all(8),
                  onSwipe: (previousIndex, currentIndex, direction) {
                    if (_isAdLoading) return false;
                    if (_swipedCount >= _currentLimit) {
                      _showAdPrompt();
                      return false;
                    }

                    final swipedItem = likers[previousIndex];
                    final swipedUser = swipedItem['profile'] as UserProfile;

                    // ডানে সোয়াইপ করলে Like Back হবে
                    if (direction == CardSwiperDirection.right) {
                      _likeBack(swipedUser);
                    }

                    setState(() {
                      _swipedCount++;
                    });

                    return true;
                  },
                  cardBuilder: (context, index, horizontalOffsetPercentage,
                      verticalOffsetPercentage) {
                    final item = likers[index];
                    final profile = item['profile'] as UserProfile;
                    final isMutual = item['isMutual'] as bool;

                    return _buildSwipeCard(profile, isMutual, bn);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    icon: Icons.close,
                    color: Colors.grey.shade400,
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
                    icon: Icons.favorite,
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
  Widget _buildSwipeCard(UserProfile user, bool isMutual, bool bn) {
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
              // Matched badge
              if (isMutual)
                Positioned(
                  top: 12,
                  left: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Colors.white, size: 13),
                          SizedBox(width: 3),
                          Text('Matched',
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
