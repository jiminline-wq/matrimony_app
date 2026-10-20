import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../models/filter_options.dart';
import '../utils/block_report_service.dart';
import '../utils/like_service.dart';
import '../utils/boost_service.dart';
import 'user_profile_view_screen.dart';
import 'filter_screen.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/verified_badge.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';

// ============================================================
// DISCOVER TAB — Card Swiper with Pagination
// ============================================================

class DiscoverTab extends StatefulWidget {
  final bool isBangla;

  const DiscoverTab({super.key, required this.isBangla});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  static const int _pageSize = 20;
  static const int _lowCardsThreshold = 5;

  List<UserProfile> users = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  String? _myGender;
  String? _myDistrict;

  FilterOptions _currentFilter = FilterOptions.empty;

  DocumentSnapshot? _lastDoc;
  Set<String> _likedUids = {};
  Set<String> _blockedUids = {};

  int _currentIndex = 0;

  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD MY INFO
  // ============================================================
  Future<void> _loadMyInfo() async {
    debugPrint('🟢 [Discover] _loadMyInfo started');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ [Discover] No user logged in');
      setState(() {
        isLoading = false;
        errorMessage = widget.isBangla ? 'আপনি লগইন করা নেই।' : 'Not logged in';
      });
      return;
    }
    debugPrint('🟢 [Discover] myUid = ${user.uid}');

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      debugPrint('🟢 [Discover] my gender = ${data['gender']}');
      debugPrint('🟢 [Discover] my district = ${data['district']}');

      setState(() {
        _myGender = (data['gender'] ?? '').toString().trim();
        _myDistrict = (data['district'] ?? '').toString().trim();
      });

      loadUsers(reset: true);
    } catch (e) {
      debugPrint('❌ [Discover] _loadMyInfo error: $e');
      loadUsers(reset: true);
    }
  }

  // ============================================================
  // LOAD USERS
  // ============================================================
  Future<void> loadUsers({bool reset = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage = widget.isBangla ? 'আপনি লগইন করা নেই।' : 'Not logged in';
      });
      return;
    }

    if (reset) {
      setState(() {
        users = [];
        _lastDoc = null;
        hasMore = true;
        isLoading = true;
        isLoadingMore = false;
        _currentIndex = 0;
        errorMessage = null;
      });

      try {
        final likedSnapshot = await FirebaseFirestore.instance
            .collection('likes')
            .doc(user.uid)
            .collection('liked')
            .get();
        _likedUids = likedSnapshot.docs.map((doc) => doc.id).toSet();

        _blockedUids = await BlockReportService.getBlockedUids(user.uid);

        debugPrint(
            '🟢 [Discover] liked=${_likedUids.length}, blocked=${_blockedUids.length}');
      } catch (e) {
        debugPrint('⚠️ [Discover] likes/blocked load failed: $e');
      }
    }

    if (!hasMore) {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      return;
    }

    try {
      final batch = await _fetchNextBatch(user.uid);
      debugPrint('🟢 [Discover] batch fetched: ${batch.length} users');

      final boostedUids = await BoostService.getBoostedUids();

      final List<UserProfile> oppositeBoosted = [];
      final List<UserProfile> oppositeNormal = [];
      final List<UserProfile> sameBoosted = [];
      final List<UserProfile> sameNormal = [];
      final List<UserProfile> unknownGender = [];

      for (final profile in batch) {
        final isBoosted = boostedUids.contains(profile.uid);
        final isOpposite = _isOppositeGender(profile.gender);
        final isSame = _isSameGender(profile.gender);

        if (isOpposite) {
          (isBoosted ? oppositeBoosted : oppositeNormal).add(profile);
        } else if (isSame) {
          (isBoosted ? sameBoosted : sameNormal).add(profile);
        } else {
          unknownGender.add(profile);
        }
      }

      final newUsers = [
        ...oppositeBoosted,
        ...oppositeNormal,
        ...sameBoosted,
        ...sameNormal,
        ...unknownGender,
      ];

      setState(() {
        users = [...users, ...newUsers];
        isLoading = false;
        isLoadingMore = false;
        errorMessage = null;
      });

      debugPrint('✅ [Discover] total users = ${users.length}');
    } catch (e) {
      debugPrint('❌ [Discover] loadUsers error: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        errorMessage = widget.isBangla
            ? 'User লিস্ট লোড করা যায়নি।'
            : 'Could not load users.';
      });
    }
  }

  // ============================================================
  // FETCH NEXT BATCH — simplified (no composite index needed)
  // ============================================================
  Future<List<UserProfile>> _fetchNextBatch(String myUid) async {
    final result = <UserProfile>[];
    int attempts = 0;

    while (result.length < _pageSize && hasMore && attempts < 5) {
      attempts++;

      Query query = FirebaseFirestore.instance.collection('users');

      // ✅ Filter conditions (single field each — no composite index)
      if (_currentFilter.gender != null) {
        query = query.where('gender', isEqualTo: _currentFilter.gender);
      }
      if (_currentFilter.district != null) {
        query = query.where('district', isEqualTo: _currentFilter.district);
      }

      // ✅ Simple orderBy on a field that exists (uid is common)
      //    Fallback: no orderBy at all if uid isn't indexed
      query = query.limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      debugPrint(
          '🟢 [Discover] attempt $attempts: got ${snapshot.docs.length} docs');

      if (snapshot.docs.isEmpty) {
        hasMore = false;
        break;
      }

      _lastDoc = snapshot.docs.last;
      hasMore = snapshot.docs.length == _pageSize;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final uid = (data['uid'] as String? ?? doc.id).trim();

        // Skip: self, empty, liked, blocked, deactivated
        if (uid.isEmpty || uid == myUid) continue;
        if (_likedUids.contains(uid)) continue;
        if (_blockedUids.contains(uid)) continue;
        if (data['isDeactivated'] == true) continue;

        final profile = UserProfile.fromMap(data, docId: doc.id);

        // Age filter
        final age = int.tryParse(profile.age);
        if (age != null) {
          if (age < _currentFilter.ageRange.start.round() ||
              age > _currentFilter.ageRange.end.round()) {
            continue;
          }
        }

        // Education filter
        if (_currentFilter.education != null &&
            !profile.education
                .toLowerCase()
                .contains(_currentFilter.education!.toLowerCase())) {
          continue;
        }

        // Profession filter
        if (_currentFilter.profession != null &&
            !profile.profession
                .toLowerCase()
                .contains(_currentFilter.profession!.toLowerCase())) {
          continue;
        }

        result.add(profile);
      }
    }

    return result;
  }

  // ============================================================
  // LOAD MORE
  // ============================================================
  Future<void> _loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    await loadUsers();
  }

  void _checkAndLoadMore(int currentIndex) {
    final remaining = users.length - currentIndex;
    if (remaining <= _lowCardsThreshold && hasMore && !isLoadingMore) {
      _loadMore();
    }
  }

  // ============================================================
  // GENDER HELPERS
  // ============================================================
  bool _isOppositeGender(String otherGender) {
    if (_myGender == null || _myGender!.isEmpty) return false;
    if (otherGender.isEmpty) return false;

    final me = _myGender!.toLowerCase().trim();
    final other = otherGender.toLowerCase().trim();

    if (me == other) return false;

    if ((me == 'male' && other == 'female') ||
        (me == 'female' && other == 'male')) {
      return true;
    }
    return false;
  }

  bool _isSameGender(String otherGender) {
    if (_myGender == null || _myGender!.isEmpty) return false;
    if (otherGender.isEmpty) return false;
    return _myGender!.toLowerCase().trim() == otherGender.toLowerCase().trim();
  }

  // ============================================================
  // LIKE USER
  // ============================================================
  Future<void> _likeUser(UserProfile targetUser) async {
    final myUser = FirebaseAuth.instance.currentUser;
    if (myUser == null) return;

    if (myUser.uid.trim().isEmpty) return;
    if (targetUser.uid.trim().isEmpty) {
      debugPrint('❌ Target uid empty — skip: ${targetUser.name}');
      return;
    }

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
                Text(
                  widget.isBangla
                      ? '${targetUser.name}-কে like করা হয়েছে'
                      : 'Liked ${targetUser.name}',
                ),
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

  // ============================================================
  // MATCH DIALOG
  // ============================================================
  void _showMatchDialog(UserProfile targetUser, String myPhotoUrl) {
    final bn = widget.isBangla;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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
                    color: mainText,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bn
                      ? 'আপনি এবং ${targetUser.name} পরস্পরকে like করেছেন।'
                      : 'You and ${targetUser.name} liked each other.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDialogPhoto(
                      myPhotoUrl, // ✅ ফায়ারস্টোর থেকে আসা ছবি
                      isMy: true,
                    ),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      bn ? 'দেখতে থাকুন' : 'Keep Swiping',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            ? Image.network(
                url,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 40, color: primaryMaroon),
              )
            : const Icon(Icons.person, size: 40, color: primaryMaroon),
      ),
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================
  Widget _buildFilterBar(bool bn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Text(
              bn ? 'আপনার পছন্দের সঙ্গী খুঁজুন' : 'Find your match',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: mainText,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push<FilterOptions>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FilterScreen(isBangla: bn, initialFilter: _currentFilter),
                ),
              );
              if (result != null) {
                setState(() => _currentFilter = result);
                loadUsers(reset: true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _currentFilter.isActive ? primaryMaroon : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryMaroon.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryMaroon.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 18,
                    color:
                        _currentFilter.isActive ? Colors.white : primaryMaroon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    bn ? 'ফিল্টার' : 'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _currentFilter.isActive
                          ? Colors.white
                          : primaryMaroon,
                    ),
                  ),
                  if (_currentFilter.isActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_currentFilter.activeCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryMaroon,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          bn ? 'আপনার সঙ্গী খুঁজুন' : 'Find Your Match',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          ChatIconButton(isBangla: bn),
          NotificationBell(isBangla: bn),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(bn),
    );
  }

  Widget _buildBody(bool bn) {
    // ---------------------------------------------------------
    // Loading
    // ---------------------------------------------------------
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      );
    }

    // ---------------------------------------------------------
    // Error
    // ---------------------------------------------------------
    if (errorMessage != null) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: primaryMaroon,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: mainText),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => loadUsers(reset: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(bn ? 'আবার চেষ্টা করুন' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ✅ Banner even in error state
          const BannerAdWidget(placementId: AdConfig.placementDiscover),
        ],
      );
    }

    // ---------------------------------------------------------
    // Empty state
    // ---------------------------------------------------------
    if (users.isEmpty) {
      return Column(
        children: [
          _buildFilterBar(bn),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentFilter.isActive
                          ? Icons.filter_alt_off
                          : Icons.person_search,
                      size: 80,
                      color: primaryMaroon,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _currentFilter.isActive
                          ? (bn
                              ? 'এই ফিল্টারে কোনো profile নেই'
                              : 'No profiles match your filter')
                          : (bn
                              ? 'কোনো profile পাওয়া যায়নি'
                              : 'No profiles found'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: mainText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentFilter.isActive
                          ? (bn
                              ? 'ফিল্টার পরিবর্তন করুন বা রিসেট করুন'
                              : 'Change or reset your filter')
                          : (bn
                              ? 'নতুন user register করলে এখানে দেখা যাবে।'
                              : 'New users will appear here.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => loadUsers(reset: true),
                          icon: const Icon(Icons.refresh),
                          label: Text(bn ? 'রিফ্রেশ' : 'Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        if (_currentFilter.isActive) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentFilter = FilterOptions.empty;
                              });
                              loadUsers(reset: true);
                            },
                            icon: const Icon(Icons.clear),
                            label: Text(bn ? 'ফিল্টার মুছুন' : 'Clear Filter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryMaroon,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              side: const BorderSide(
                                color: primaryMaroon,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ✅ Banner even in empty state
          const BannerAdWidget(placementId: AdConfig.placementDiscover),
        ],
      );
    }

    // ---------------------------------------------------------
    // Normal state — swipe cards + banner
    // ---------------------------------------------------------
    return Column(
      children: [
        _buildFilterBar(bn),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Expanded(
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: users.length,
                    numberOfCardsDisplayed: users.length < 2 ? users.length : 2,
                    backCardOffset: const Offset(0, 30),
                    padding: const EdgeInsets.all(8),
                    onSwipe: (previousIndex, currentIndex, direction) {
                      final swipedUser = users[previousIndex];
                      if (direction == CardSwiperDirection.right) {
                        _likeUser(swipedUser);
                      }
                      if (currentIndex != null) {
                        _currentIndex = currentIndex;
                        _checkAndLoadMore(currentIndex);
                      }
                      return true;
                    },
                    cardBuilder: (
                      context,
                      index,
                      horizontalOffsetPercentage,
                      verticalOffsetPercentage,
                    ) {
                      return _buildSwipeCard(users[index], bn);
                    },
                  ),
                ),
                if (isLoadingMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: primaryMaroon,
                            strokeWidth: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          bn ? 'আরো লোড হচ্ছে...' : 'Loading more...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                        _swiperController.swipe(CardSwiperDirection.left);
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.favorite,
                      color: primaryMaroon,
                      onTap: () {
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
        const BannerAdWidget(placementId: AdConfig.placementDiscover),
      ],
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
            builder: (_) => UserProfileViewScreen(isBangla: bn, user: user),
          ),
        );
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
              offset: const Offset(0, 8),
            ),
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
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: primaryMaroon,
                          ),
                        ),
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
                          Colors.black.withValues(alpha: 0.85),
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
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryGold, primaryMaroon],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: Colors.white, size: 13),
                          SizedBox(width: 3),
                          Text(
                            'Boosted',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bn ? 'দেখতে ট্যাপ' : 'Tap to view',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                                      color: Colors.white,
                                    ),
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
                            Text(
                              user.age,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              user.district.isEmpty ? '—' : user.district,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
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
                            const Icon(
                              Icons.work_outline,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                user.profession,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
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

  // ============================================================
  // ACTION BUTTON
  // ============================================================
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
              offset: const Offset(0, 5),
            ),
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
        // ✅ পরিবর্তিত কোড:
        CachedNetworkImage(
          imageUrl: widget.photoUrls[_currentIndex],
          fit: BoxFit.cover,
          placeholder: (_, __) =>
              Container(color: lightMaroon), // লোড হওয়ার সময়
          errorWidget: (_, __, ___) => Container(
            color: lightMaroon,
            child: const Center(
              child: Icon(Icons.person, size: 100, color: primaryMaroon),
            ),
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
