import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/boost_service.dart';
import '../utils/like_service.dart';
import '../utils/block_report_service.dart';
import 'user_profile_view_screen.dart';
import '../widgets/verified_badge.dart';
import '../ads/rewarded_ad_manager.dart';

class DistrictUsersScreen extends StatefulWidget {
  final bool isBangla;
  final String district;

  const DistrictUsersScreen({
    super.key,
    required this.isBangla,
    required this.district,
  });

  @override
  State<DistrictUsersScreen> createState() => _DistrictUsersScreenState();
}

class _DistrictUsersScreenState extends State<DistrictUsersScreen> {
  String? _myUid;
  String? _oppositeGender;

  bool _isLoading = true;
  String? _errorMessage;
  List<UserProfile> _users = [];
  Set<String> _likedUids = {};
  Set<String> _blockedUids = {};

  // ✅ রিওয়ার্ডেড অ্যাড লিমিট স্টেট
  int _swipedCount = 0;
  int _currentLimit = 10; // প্রতি ১০টি সোয়াইপে অ্যাড
  bool _isAdLoading = false;

  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    _load();
    RewardedAdManager.loadAd();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _myUid = uid;

    try {
      final myDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final myGender = (myDoc.data()?['gender'] ?? '').toString().toLowerCase();

      if (myGender == 'male') {
        _oppositeGender = 'Female';
      } else if (myGender == 'female') {
        _oppositeGender = 'Male';
      }

      // ✅ লাইক এবং ব্লক করা ইউজার লোড করা
      try {
        final likedSnap = await FirebaseFirestore.instance
            .collection('likes')
            .doc(uid)
            .collection('liked')
            .get();
        _likedUids = likedSnap.docs.map((d) => d.id).toSet();
        _blockedUids = await BlockReportService.getBlockedUids(uid);
      } catch (_) {}

      Query q = FirebaseFirestore.instance
          .collection('users')
          .where('district', isEqualTo: widget.district)
          .limit(50);

      if (_oppositeGender != null) {
        q = q.where('gender', isEqualTo: _oppositeGender);
      }

      final snap = await q.get();
      final users = <UserProfile>[];

      for (final doc in snap.docs) {
        if (doc.id == uid) continue;
        if (_likedUids.contains(doc.id)) continue; // ✅ লাইক করা বাদ যাবে
        if (_blockedUids.contains(doc.id)) continue; // ✅ ব্লক করা বাদ যাবে

        final data = doc.data() as Map<String, dynamic>;
        if (data['isDeactivated'] == true) continue;
        users.add(UserProfile.fromMap(data, docId: doc.id));
      }

      users.sort((a, b) {
        final aB = BoostService.isBoostActive(a.boostedUntil) ? 0 : 1;
        final bB = BoostService.isBoostActive(b.boostedUntil) ? 0 : 1;
        return aB.compareTo(bB);
      });

      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            widget.isBangla ? 'লিস্ট লোড করা যায়নি' : 'Could not load list';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // LIKE USER & MATCH DIALOG
  // ============================================================
  Future<void> _likeUser(UserProfile targetUser) async {
    final myUser = FirebaseAuth.instance.currentUser;
    if (myUser == null) return;
    if (myUser.uid.trim().isEmpty || targetUser.uid.trim().isEmpty) return;

    try {
      await LikeService.likeUser(myUid: myUser.uid, theirUid: targetUser.uid);

      final theirLikeDoc = await FirebaseFirestore.instance
          .collection('likes')
          .doc(targetUser.uid)
          .collection('liked')
          .doc(myUser.uid)
          .get();

      if (theirLikeDoc.exists) {
        final myProfileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUser.uid)
            .get();
        final myData = myProfileDoc.data() ?? {};

        final matchId = _generateMatchId(myUser.uid, targetUser.uid);
        if (matchId.isEmpty) return;

        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .set({
          'users': [myUser.uid, targetUser.uid],
          'user1': {
            'uid': myUser.uid,
            'name': myData['name'] ?? '',
            'photoUrl': myData['photoUrl'] ?? '',
            'age': myData['age'] ?? '',
            'district': myData['district'] ?? '',
          },
          'user2': {
            'uid': targetUser.uid,
            'name': targetUser.name,
            'photoUrl': targetUser.photoUrl,
            'age': targetUser.age,
            'district': targetUser.district,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _showMatchDialog(targetUser, myData['photoUrl'] as String? ?? '');
      } else {
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
      }
    } catch (e) {
      debugPrint('❌ likeUser error: $e');
    }
  }

  String _generateMatchId(String uid1, String uid2) {
    if (uid1.trim().isEmpty || uid2.trim().isEmpty) return '';
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  void _showMatchDialog(UserProfile targetUser, String myPhotoUrl) {
    final bn = widget.isBangla;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [lightMaroon, lightGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 70, color: primaryMaroon),
                const SizedBox(height: 16),
                Text(
                  bn ? '🎉 এটা একটা Match!' : '🎉 It\'s a Match!',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: mainText),
                ),
                const SizedBox(height: 10),
                Text(
                  bn
                      ? 'আপনি এবং ${targetUser.name} পরস্পরকে like করেছেন।'
                      : 'You and ${targetUser.name} liked each other.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: secondaryText, height: 1.5),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDialogPhoto(myPhotoUrl, isMy: true),
                    Transform.translate(
                      offset: const Offset(-12, 0),
                      child:
                          _buildDialogPhoto(targetUser.photoUrl, isMy: false),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(bn ? 'দেখতে থাকুন' : 'Keep Swiping',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogPhoto(String? url, {required bool isMy}) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: primaryGold, width: 3),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? AppNetworkImage(url,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 40, color: primaryMaroon))
            : const Icon(Icons.person, size: 40, color: primaryMaroon),
      ),
    );
  }

  // ============================================================
  // ✅ রিওয়ার্ডেড অ্যাড প্রম্পট ডায়ালগ
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
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryMaroon),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.district,
                style: const TextStyle(
                    color: deepMaroon,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(
                bn
                    ? '${_users.length}টি প্রোফাইল'
                    : '${_users.length} profiles',
                style: const TextStyle(color: secondaryText, fontSize: 11)),
          ],
        ),
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_users.isEmpty) {
      return Center(
          child: Text(bn ? 'কেউ নেই' : 'No one found',
              style: const TextStyle(fontSize: 16, color: secondaryText)));
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
                  cardsCount: _users.length,
                  numberOfCardsDisplayed: _users.length < 2 ? _users.length : 2,
                  backCardOffset: const Offset(0, 30),
                  padding: const EdgeInsets.all(8),
                  onSwipe: (previousIndex, currentIndex, direction) {
                    if (_isAdLoading) return false;
                    if (_swipedCount >= _currentLimit) {
                      _showAdPrompt();
                      return false;
                    }

                    final swipedUser = _users[previousIndex];
                    if (direction == CardSwiperDirection.right) {
                      _likeUser(swipedUser);
                    }

                    setState(() {
                      _swipedCount++;
                    });

                    return true;
                  },
                  cardBuilder: (context, index, horizontalOffsetPercentage,
                      verticalOffsetPercentage) {
                    return _buildSwipeCard(_users[index], bn);
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
  Widget _buildSwipeCard(UserProfile user, bool bn) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfileViewScreen(
                    isBangla: widget.isBangla, user: user)));
      },
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
              if (BoostService.isBoostActive(user.boostedUntil))
                Positioned(
                  top: 12,
                  left: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [primaryGold, primaryMaroon]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.white, size: 13),
                          SizedBox(width: 3),
                          Text('Boosted',
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
                      if (user.profession.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.work_outline,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                user.profession,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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
