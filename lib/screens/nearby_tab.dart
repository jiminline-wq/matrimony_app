import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/block_report_service.dart';
import '../utils/like_service.dart';
import '../utils/boost_service.dart';
import '../utils/bd_districts.dart';
import '../services/location_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/verified_badge.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../ads/rewarded_ad_manager.dart'; // ✅ রিওয়ার্ডেড অ্যাড ম্যানেজার ইম্পোর্ট

// ✅ Deferred Loading Import for UserProfileViewScreen
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

// ============================================================
// NEARBY TAB — Card Swiper with Location Radius & Rewarded Ad
// ============================================================

class NearbyTab extends StatefulWidget {
  final bool isBangla;

  const NearbyTab({super.key, required this.isBangla});

  @override
  State<NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<NearbyTab> {
  static const int _pageSize = 20;
  static const double _maxRadiusKm = 20.0;

  String? _selectedDistrict;
  String? _myGender;
  String? _oppositeGender;
  String _searchQuery = '';

  double? _myLat;
  double? _myLng;

  final Map<String, Map<String, double>> _userLocationCache = {};

  List<UserProfile> users = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  DocumentSnapshot? _lastDoc;
  Set<String> _likedUids = {};
  Set<String> _blockedUids = {};

  int _currentIndex = 0;

  // ✅ রিওয়ার্ডেড অ্যাড লিমিট স্টেট
  int _swipedCount = 0;
  int _currentLimit = 10; // প্রতি ১০টি সোয়াইপে অ্যাড
  bool _isAdLoading = false;

  final TextEditingController _searchController = TextEditingController();
  final CardSwiperController _swiperController = CardSwiperController();

  @override
  void initState() {
    super.initState();
    _initData();
    RewardedAdManager.loadAd(); // ✅ অ্যাড প্রি-লোড করা হচ্ছে
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        isLoading = false;
        errorMessage = widget.isBangla ? 'আপনি লগইন করা নেই।' : 'Not logged in';
      });
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final myDistrict = (data['district'] ?? '').toString().trim();
      final myGender = (data['gender'] ?? '').toString().trim();

      final loc = data['location'] as Map<String, dynamic>?;
      final myLat = (loc?['lat'] as num?)?.toDouble();
      final myLng = (loc?['lng'] as num?)?.toDouble();

      setState(() {
        _myGender = myGender;
        _myLat = myLat;
        _myLng = myLng;

        if (myGender.toLowerCase() == 'male') {
          _oppositeGender = 'Female';
        } else if (myGender.toLowerCase() == 'female') {
          _oppositeGender = 'Male';
        } else {
          _oppositeGender = null;
        }

        _selectedDistrict =
            myDistrict.isNotEmpty && bdDistricts.contains(myDistrict)
                ? myDistrict
                : bdDistricts.first;
      });

      _loadUsers(reset: true);
    } catch (_) {
      setState(() => _selectedDistrict = bdDistricts.first);
      _loadUsers(reset: true);
    }
  }

  Future<void> _loadUsers({bool reset = false}) async {
    if (_selectedDistrict == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (reset) {
      setState(() {
        users = [];
        _lastDoc = null;
        hasMore = true;
        isLoading = true;
        isLoadingMore = false;
        _currentIndex = 0;
        errorMessage = null;
        // ✅ লিস্ট রিসেট হলে কাউন্টারও রিসেট হবে
        _swipedCount = 0;
        _currentLimit = 10;
      });

      try {
        final myDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final loc = myDoc.data()?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          _myLat = (loc['lat'] as num?)?.toDouble();
          _myLng = (loc['lng'] as num?)?.toDouble();
        }
      } catch (_) {}

      try {
        final likedSnap = await FirebaseFirestore.instance
            .collection('likes')
            .doc(uid)
            .collection('liked')
            .get();
        _likedUids = likedSnap.docs.map((d) => d.id).toSet();
        _blockedUids = await BlockReportService.getBlockedUids(uid);
      } catch (_) {}
    }

    if (!hasMore) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final batch = await _fetchNextBatch(uid);
      await _loadLocationsForUsers(batch);

      final List<UserProfile> withinRadius = [];
      for (final user in batch) {
        final lat = _getUserLat(user);
        final lng = _getUserLng(user);
        if (lat == null || lng == null) continue;
        final km = LocationService.calculateDistance(_myLat, _myLng, lat, lng);
        if (km == null) continue;
        if (km <= _maxRadiusKm) withinRadius.add(user);
      }

      withinRadius.sort((a, b) {
        final aKm = LocationService.calculateDistance(
                _myLat, _myLng, _getUserLat(a), _getUserLng(a)) ??
            9999;
        final bKm = LocationService.calculateDistance(
                _myLat, _myLng, _getUserLat(b), _getUserLng(b)) ??
            9999;
        return aKm.compareTo(bKm);
      });

      final boosted = withinRadius
          .where((u) => BoostService.isBoostActive(u.boostedUntil))
          .toList();
      final normal = withinRadius
          .where((u) => !BoostService.isBoostActive(u.boostedUntil))
          .toList();

      setState(() {
        users = [...users, ...boosted, ...normal];
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        errorMessage =
            widget.isBangla ? 'লিস্ট লোড করা যায়নি' : 'Could not load list';
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<List<UserProfile>> _fetchNextBatch(String myUid) async {
    final result = <UserProfile>[];
    int attempts = 0;

    while (result.length < _pageSize && hasMore && attempts < 5) {
      attempts++;
      Query q = FirebaseFirestore.instance.collection('users');

      if (_selectedDistrict != null)
        q = q.where('district', isEqualTo: _selectedDistrict);
      if (_oppositeGender != null)
        q = q.where('gender', isEqualTo: _oppositeGender);

      q = q.orderBy(FieldPath.documentId);
      q = q.limit(_pageSize);

      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);

      final snap = await q.get();

      if (snap.docs.isEmpty) {
        hasMore = false;
        break;
      }

      _lastDoc = snap.docs.last;
      hasMore = snap.docs.length == _pageSize;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final u = (data['uid'] ?? '').toString();

        if (u.isEmpty || u == myUid) continue;
        if (_likedUids.contains(u)) continue;
        if (_blockedUids.contains(u)) continue;
        if (data['isDeactivated'] == true) continue;

        result.add(UserProfile.fromMap(data, docId: doc.id));
      }
    }
    return result;
  }

  Future<void> _loadLocationsForUsers(List<UserProfile> users) async {
    final futures = <Future>[];
    for (final user in users) {
      if (_userLocationCache.containsKey(user.uid)) continue;
      futures.add(() async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final loc = doc.data()?['location'] as Map<String, dynamic>?;
          if (loc != null) {
            _userLocationCache[user.uid] = {
              'lat': (loc['lat'] as num).toDouble(),
              'lng': (loc['lng'] as num).toDouble(),
            };
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
  }

  double? _getUserLat(UserProfile user) => _userLocationCache[user.uid]?['lat'];
  double? _getUserLng(UserProfile user) => _userLocationCache[user.uid]?['lng'];

  Future<void> _loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    await _loadUsers();
  }

  List<UserProfile> get _filteredUsers {
    if (_searchQuery.isEmpty) return users;
    final q = _searchQuery.toLowerCase();
    return users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.profession.toLowerCase().contains(q) ||
          u.education.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistrictPickerSheet(
        current: _selectedDistrict,
        isBangla: widget.isBangla,
      ),
    );

    if (picked != null && picked != _selectedDistrict) {
      setState(() {
        _selectedDistrict = picked;
        _searchController.clear();
        _searchQuery = '';
      });
      _loadUsers(reset: true);
    }
  }

  // ✅ DEFERRED NAVIGATION HELPER FOR PROFILE VIEW
  Future<void> _openProfile(UserProfile user) async {
    if (_isAdLoading) return;

    // প্রোফাইল দেখার সময়ও চেক করা হবে (ঐচ্ছিক, তবে ভালো অভিজ্ঞতার জন্য)
    if (_swipedCount >= _currentLimit) {
      _showAdPrompt();
      return;
    }

    setState(() => _swipedCount++); // কাউন্ট বাড়ানো হলো

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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => user_profile_view_lib.UserProfileViewScreen(
            isBangla: widget.isBangla,
            user: user,
          ),
        ),
      );
      if (mounted) _loadUsers(reset: true);
    }
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
                // ওয়েবে রিওয়ার্ডেড অ্যাড কাজ করে না, তাই সরাসরি আনলক
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
  // LIKE USER
  // ============================================================
  Future<void> _likeUser(UserProfile targetUser) async {
    final myUser = FirebaseAuth.instance.currentUser;
    if (myUser == null) return;

    if (myUser.uid.trim().isEmpty) return;
    if (targetUser.uid.trim().isEmpty) return;

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
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return Scaffold(
          backgroundColor: warmWhite,
          appBar: AppBar(
            backgroundColor: warmWhite,
            elevation: 0,
            centerTitle: isDesktop,
            automaticallyImplyLeading: false,
            title: Text(
              bn ? 'কাছের মানুষ' : 'Nearby',
              style: const TextStyle(
                  color: deepMaroon, fontWeight: FontWeight.bold),
            ),
            actions: [
              ChatIconButton(isBangla: bn),
              NotificationBell(isBangla: bn),
              IconButton(
                onPressed: () => _loadUsers(reset: true),
                icon: const Icon(Icons.refresh, color: primaryMaroon),
              ),
            ],
          ),
          body: Column(
            children: [
              // 📱 ফিল্টার বার
              _buildFilterBar(bn),

              Expanded(
                child: isDesktop ? _buildWebBody(bn) : _buildMobileBody(bn),
              ),

              // ✅ AdMob শুধু মোবাইলে
              if (!kIsWeb)
                const SafeArea(
                  top: false,
                  child: BannerAdWidget(placementId: AdConfig.placementNearby),
                ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FILTER BAR
  // ============================================================
  Widget _buildFilterBar(bool bn) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: _pickDistrict,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: primaryMaroon.withValues(alpha: 0.25),
                          width: 1.4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city,
                            color: primaryMaroon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDistrict ?? '—',
                            style: const TextStyle(
                                fontSize: 14,
                                color: mainText,
                                fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: primaryMaroon, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(fontSize: 14, color: mainText),
                  decoration: InputDecoration(
                    hintText: bn ? 'খুঁজুন' : 'Search',
                    hintStyle:
                        const TextStyle(fontSize: 13, color: secondaryText),
                    prefixIcon: const Icon(Icons.search,
                        color: primaryMaroon, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: primaryMaroon.withValues(alpha: 0.15),
                          width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: primaryMaroon, width: 1.6),
                    ),
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
  // 📱 মোবাইল বডি (Card Swiper)
  // ============================================================
  Widget _buildMobileBody(bool bn) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
    }
    if (errorMessage != null) return _buildError(bn);

    final filtered = _filteredUsers;
    final noLocation = _myLat == null || _myLng == null;

    if (filtered.isEmpty) return _buildEmptyState(bn, noLocation);

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
                  cardsCount: filtered.length,
                  numberOfCardsDisplayed:
                      filtered.length < 2 ? filtered.length : 2,
                  backCardOffset: const Offset(0, 30),
                  padding: const EdgeInsets.all(8),
                  onSwipe: (previousIndex, currentIndex, direction) {
                    if (_isAdLoading) return false;
                    if (_swipedCount >= _currentLimit) {
                      _showAdPrompt();
                      return false;
                    }

                    final swipedUser = filtered[previousIndex];
                    if (direction == CardSwiperDirection.right) {
                      _likeUser(swipedUser);
                    }

                    setState(() {
                      _swipedCount++;
                    });

                    if (currentIndex != null) {
                      _currentIndex = currentIndex;
                      if (filtered.length - currentIndex < 5 && hasMore) {
                        _loadMore();
                      }
                    }
                    return true;
                  },
                  cardBuilder: (context, index, horizontalOffsetPercentage,
                      verticalOffsetPercentage) {
                    return _buildSwipeCard(filtered[index], bn);
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
                              color: primaryMaroon, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(bn ? 'আরো লোড হচ্ছে...' : 'Loading more...',
                          style: const TextStyle(
                              fontSize: 12, color: secondaryText)),
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
  // 💻 ওয়েব বডি (Card Swiper)
  // ============================================================
  Widget _buildWebBody(bool bn) {
    return _buildMobileBody(bn);
  }

  // ============================================================
  // SWIPE CARD (With Distance)
  // ============================================================
  Widget _buildSwipeCard(UserProfile user, bool bn) {
    final isBoosted = BoostService.isBoostActive(user.boostedUntil);
    final km = LocationService.calculateDistance(
        _myLat, _myLng, _getUserLat(user), _getUserLng(user));

    return GestureDetector(
      onTap: () => _openProfile(user),
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
              if (isBoosted)
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
                          // ✅ দূরত্ব দেখানোর চিপ
                          if (km != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                km < 1
                                    ? (bn
                                        ? '${(km * 1000).round()} মি'
                                        : '${(km * 1000).round()}m')
                                    : (bn
                                        ? '${km.toStringAsFixed(1)} কিমি'
                                        : '${km.toStringAsFixed(1)}km'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
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

  Widget _buildError(bool bn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: primaryMaroon),
            const SizedBox(height: 16),
            Text(errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: mainText)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadUsers(reset: true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white),
              child: Text(bn ? 'আবার চেষ্টা' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool bn, bool noLocation) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noLocation
                  ? Icons.location_off
                  : (_searchQuery.isNotEmpty
                      ? Icons.search_off
                      : Icons.person_search),
              size: 80,
              color: primaryMaroon.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 18),
            Text(
              noLocation
                  ? (bn ? 'Location চালু করুন' : 'Enable Location')
                  : (_searchQuery.isNotEmpty
                      ? (bn ? 'কিছু পাওয়া যায়নি' : 'No results found')
                      : (bn
                          ? '২০ কিমি এর মধ্যে কেউ নেই'
                          : 'No one within 20 km')),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: mainText),
            ),
            const SizedBox(height: 8),
            Text(
              noLocation
                  ? (bn
                      ? 'কাছের মানুষ দেখতে location permission দিন'
                      : 'Grant location permission to see nearby people')
                  : (bn
                      ? 'অন্য জেলা বেছে নিন বা রিফ্রেশ করুন'
                      : 'Try another district or refresh'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: secondaryText),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: noLocation
                  ? () async {
                      final granted = await LocationService.requestPermission();
                      if (granted) {
                        await LocationService.saveLocationToFirestore();
                        _initData();
                      }
                    }
                  : _pickDistrict,
              icon: Icon(noLocation ? Icons.my_location : Icons.swap_horiz),
              label: Text(noLocation
                  ? (bn ? 'Location চালু করুন' : 'Enable Location')
                  : (bn ? 'জেলা বদলান' : 'Change District')),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
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

// ============================================================
// DISTRICT PICKER SHEET
// ============================================================
class _DistrictPickerSheet extends StatefulWidget {
  final String? current;
  final bool isBangla;

  const _DistrictPickerSheet({this.current, required this.isBangla});

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  String _query = '';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    final list = bdDistricts
        .where((d) => d.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Material(
              color: warmWhite,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                        color: secondaryText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_city,
                            color: primaryMaroon, size: 22),
                        const SizedBox(width: 8),
                        Text(bn ? 'জেলা নির্বাচন' : 'Select District',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: deepMaroon)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: bn ? 'জেলা খুঁজুন' : 'Search district',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: primaryMaroon, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: primaryMaroon.withValues(alpha: 0.15),
                                width: 1.2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: primaryMaroon, width: 1.6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                                bn
                                    ? 'কোনো জেলা পাওয়া যায়নি'
                                    : 'No district found',
                                style: const TextStyle(color: secondaryText)))
                        : ListView.separated(
                            controller: scrollCtrl,
                            itemCount: list.length,
                            separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: primaryMaroon.withValues(alpha: 0.08)),
                            itemBuilder: (_, i) {
                              final d = list[i];
                              final selected = d == widget.current;
                              return Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  onTap: () => Navigator.pop(context, d),
                                  leading: Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: selected
                                        ? primaryMaroon
                                        : secondaryText.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                  title: Text(d,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: selected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: selected
                                              ? primaryMaroon
                                              : mainText)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
