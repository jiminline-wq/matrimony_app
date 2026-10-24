import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এবং defaultTargetPlatform এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/block_report_service.dart';
import '../utils/boost_service.dart';
import '../utils/bd_districts.dart';
import '../services/location_service.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';

// ✅ Deferred Loading Import for UserProfileViewScreen
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

// ============================================================
// NEARBY TAB
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

  List<UserProfile> _allUsers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  DocumentSnapshot? _lastDoc;
  Set<String> _likedUids = {};
  Set<String> _blockedUids = {};

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current < 300) {
      _loadMore();
    }
  }

  Future<void> _initData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            widget.isBangla ? 'আপনি লগইন করা নেই।' : 'Not logged in';
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
        _allUsers = [];
        _lastDoc = null;
        _hasMore = true;
        _isLoading = true;
        _errorMessage = null;
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

    if (!_hasMore) {
      setState(() => _isLoading = false);
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
        _allUsers = [..._allUsers, ...boosted, ...normal];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            widget.isBangla ? 'লিস্ট লোড করা যায়নি' : 'Could not load list';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<List<UserProfile>> _fetchNextBatch(String myUid) async {
    final result = <UserProfile>[];
    int attempts = 0;

    while (result.length < _pageSize && _hasMore && attempts < 5) {
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
        _hasMore = false;
        break;
      }

      _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length == _pageSize;

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
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadUsers();
  }

  List<UserProfile> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;
    final q = _searchQuery.toLowerCase();
    return _allUsers.where((u) {
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
  // BUILD (Responsive Layout Switcher)
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
            centerTitle: isDesktop, // ওয়েবে সেন্টার, মোবাইলে লেফট
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
              // 📱 মোবাইল ফিল্টার বার
              if (!isDesktop) ...[
                _buildGenderHint(bn),
                _buildDistrictBar(bn),
                _buildSearchBar(bn),
              ],

              // 💻 ওয়েব ফিল্টার বার (পাশাপাশি)
              if (isDesktop)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: _buildDistrictBar(bn)),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: _buildSearchBar(bn)),
                        ],
                      ),
                    ),
                  ),
                ),

              // মেইন বডি
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

  // -------- Gender hint --------
  Widget _buildGenderHint(bool bn) {
    if (_oppositeGender == null) return const SizedBox.shrink();
    final isFemale = _oppositeGender == 'Female';
    final hasLocation = _myLat != null && _myLng != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isFemale ? const Color(0xFFF7EBEE) : const Color(0xFFEAF1FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (isFemale ? primaryMaroon : Colors.blue)
                  .withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(isFemale ? Icons.female : Icons.male,
                size: 16,
                color: isFemale ? primaryMaroon : Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLocation
                    ? (bn
                        ? '${isFemale ? "মহিলা" : "পুরুষ"} · ২০ কিমি এর মধ্যে'
                        : '${isFemale ? "Female" : "Male"} · within 20 km')
                    : (bn
                        ? 'শুধু ${isFemale ? "মহিলা" : "পুরুষ"} প্রোফাইল'
                        : 'Showing ${isFemale ? "female" : "male"} only'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFemale ? deepMaroon : Colors.blue.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------- District bar --------
  Widget _buildDistrictBar(bool bn) {
    return GestureDetector(
      onTap: _pickDistrict,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: primaryMaroon.withValues(alpha: 0.25), width: 1.4),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city, color: primaryMaroon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bn ? 'জেলা' : 'District',
                      style: const TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(_selectedDistrict ?? '—',
                      style: const TextStyle(
                          fontSize: 15,
                          color: mainText,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: primaryMaroon),
          ],
        ),
      ),
    );
  }

  // -------- Search bar --------
  Widget _buildSearchBar(bool bn) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      style: const TextStyle(fontSize: 14, color: mainText),
      decoration: InputDecoration(
        hintText:
            bn ? 'নাম / পেশা / শিক্ষা খুঁজুন' : 'Search name / profession',
        hintStyle: const TextStyle(fontSize: 13, color: secondaryText),
        prefixIcon: const Icon(Icons.search, color: primaryMaroon, size: 20),
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
              color: primaryMaroon.withValues(alpha: 0.15), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryMaroon, width: 1.6),
        ),
      ),
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল বডি (Original)
  // ============================================================
  Widget _buildMobileBody(bool bn) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
    if (_errorMessage != null) return _buildError(bn);

    final users = _filteredUsers;
    final noLocation = _myLat == null || _myLng == null;

    if (users.isEmpty) return _buildEmptyState(bn, noLocation);

    final itemCount = users.length + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      color: primaryMaroon,
      onRefresh: () => _loadUsers(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          if (i == users.length) return _buildLoadMoreIndicator(bn);
          return _buildMobileUserCard(users[i], bn);
        },
      ),
    );
  }

  Widget _buildMobileUserCard(UserProfile user, bool bn) {
    final isBoosted = BoostService.isBoostActive(user.boostedUntil);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: primaryMaroon.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openProfile(user),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: lightMaroon),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: user.photoUrl.isNotEmpty
                            ? AppNetworkImage(user.photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: primaryMaroon))
                            : const Icon(Icons.person,
                                size: 40, color: primaryMaroon),
                      ),
                    ),
                    if (isBoosted)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [primaryGold, primaryMaroon]),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: Colors.white, size: 10),
                                SizedBox(width: 2),
                                Text('Boost',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold))
                              ]),
                        ),
                      ),
                  ],
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
                                  user.name.isEmpty
                                      ? (bn ? 'নাম নেই' : 'No name')
                                      : user.name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: mainText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (user.age.isNotEmpty)
                            Text('• ${user.age}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: secondaryText,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 13, color: secondaryText),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(
                                  user.district.isEmpty ? '—' : user.district,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: secondaryText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (_myLat != null && _myLng != null)
                            _buildDistanceChip(user, bn),
                        ],
                      ),
                      if (user.profession.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _row(Icons.work_outline, user.profession)
                      ],
                      if (user.education.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _row(Icons.school_outlined, user.education)
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: secondaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব বডি (Grid View)
  // ============================================================
  Widget _buildWebBody(bool bn) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
    if (_errorMessage != null) return _buildError(bn);

    final users = _filteredUsers;
    final noLocation = _myLat == null || _myLng == null;

    if (users.isEmpty) return _buildEmptyState(bn, noLocation);

    final itemCount = users.length + (_hasMore ? 1 : 0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // ওয়েবে এক লাইনে ৩টি কার্ড
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.8, // কার্ডের সাইজ
          ),
          itemCount: itemCount,
          itemBuilder: (context, i) {
            if (i == users.length) return _buildLoadMoreIndicator(bn);
            return _buildWebUserCard(users[i], bn);
          },
        ),
      ),
    );
  }

  Widget _buildWebUserCard(UserProfile user, bool bn) {
    final isBoosted = BoostService.isBoostActive(user.boostedUntil);

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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openProfile(user),
          hoverColor: primaryMaroon.withValues(alpha: 0.03),
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
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: user.photoUrl.isNotEmpty
                          ? AppNetworkImage(user.photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder())
                          : _imgPlaceholder(),
                    ),
                    // গ্রেডিয়েন্ট ওভারলে
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                    // নাম ও বয়স
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              user.name.isEmpty
                                  ? (bn ? 'নাম নেই' : 'No name')
                                  : user.name,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.age.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(user.age,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                        ],
                      ),
                    ),
                    // Boost Tag
                    if (isBoosted)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [primaryGold, primaryMaroon]),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text('Boost',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold))
                              ]),
                        ),
                      ),
                  ],
                ),
              ),
              // টেক্সট ডিটেইলস
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16, color: primaryMaroon),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(
                                      user.district.isEmpty
                                          ? '—'
                                          : user.district,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: secondaryText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              if (_myLat != null && _myLng != null)
                                _buildDistanceChip(user, bn),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (user.profession.isNotEmpty)
                            _webRow(Icons.work_outline, user.profession),
                          if (user.profession.isNotEmpty)
                            const SizedBox(height: 6),
                          if (user.education.isNotEmpty)
                            _webRow(Icons.school_outlined, user.education),
                        ],
                      ),
                      // View Profile Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _openProfile(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryMaroon,
                            side: BorderSide(
                                color: primaryMaroon.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(bn ? 'প্রোফাইল দেখুন' : 'View Profile',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
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

  Widget _imgPlaceholder() {
    return Container(
      color: lightMaroon,
      child: const Center(
          child: Icon(Icons.person, size: 80, color: primaryMaroon)),
    );
  }

  Widget _webRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: secondaryText),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text.isEmpty ? '—' : text,
                style: const TextStyle(fontSize: 13, color: secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ============================================================
  // COMMON WIDGETS
  // ============================================================

  Widget _buildError(bool bn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: primaryMaroon),
            const SizedBox(height: 16),
            Text(_errorMessage!,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: mainText),
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
                      style:
                          const TextStyle(fontSize: 13, color: secondaryText),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: noLocation
                          ? () async {
                              final granted =
                                  await LocationService.requestPermission();
                              if (granted) {
                                await LocationService.saveLocationToFirestore();
                                _initData();
                              }
                            }
                          : _pickDistrict,
                      icon: Icon(
                          noLocation ? Icons.my_location : Icons.swap_horiz),
                      label: Text(noLocation
                          ? (bn ? 'Location চালু করুন' : 'Enable Location')
                          : (bn ? 'জেলা বদলান' : 'Change District')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistanceChip(UserProfile user, bool bn) {
    final lat = _getUserLat(user);
    final lng = _getUserLng(user);
    final km = LocationService.calculateDistance(_myLat, _myLng, lat, lng);
    if (km == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: lightMaroon,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me, size: 10, color: primaryMaroon),
          const SizedBox(width: 3),
          Text(
            km < 1
                ? (bn ? '${(km * 1000).round()} মি' : '${(km * 1000).round()}m')
                : (bn
                    ? '${km.toStringAsFixed(1)} কিমি'
                    : '${km.toStringAsFixed(1)}km'),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: primaryMaroon),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: secondaryText),
        const SizedBox(width: 4),
        Expanded(
            child: Text(text.isEmpty ? '—' : text,
                style: const TextStyle(fontSize: 12.5, color: secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildLoadMoreIndicator(bool bn) {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: primaryMaroon, strokeWidth: 2.5))),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(bn ? 'আরো লোড করুন' : 'Load More',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(foregroundColor: primaryMaroon),
        ),
      ),
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
        // ওয়েবের জন্য একটি ConstrainedBox যুক্ত করা হলো যাতে পুরো স্ক্রিন জুড়ে না যায়
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
