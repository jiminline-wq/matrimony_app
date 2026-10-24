import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb er jonno
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../models/success_story.dart';
import '../services/success_story_service.dart';
import '../utils/bd_districts.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/notification_bell.dart';
import 'nearby_tab.dart';
import 'discover_tab.dart';
import 'matches_tab.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../widgets/stories_row.dart';
import '../widgets/profile_completeness_card.dart';
import '../services/engagement_service.dart';
import '../widgets/streak_card.dart';

// ✅ Deferred Loading Imports
import 'district_users_screen.dart' deferred as district_users_lib;
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;
import 'who_liked_me_screen.dart' deferred as who_liked_me_lib;
import 'shortlist_screen.dart' deferred as shortlist_lib;
import 'story_details_screen.dart' deferred as story_details_lib;
import 'submit_story_screen.dart' deferred as submit_story_lib;
import 'edit_profile_screen.dart' deferred as edit_profile_lib;

// ============================================================
// HOME TAB — Matrimonial.com.bd style full home page
// ============================================================

class HomeTab extends StatefulWidget {
  final bool isBangla;

  const HomeTab({super.key, required this.isBangla});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _myName = '';
  String? _myPhoto = '';
  String? _myUid;
  Map<String, dynamic>? _myProfileData;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
    _checkDailyStreak();
  }

  // ✅ DEFERRED NAVIGATION HELPER
  Future<void> _navigateDeferred(
    Future<void> libraryLoader,
    Widget Function() screenBuilder,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await libraryLoader;

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screenBuilder()),
      );
    }
  }

  // ✅ ১. ডেইলি স্ট্রিক আপডেট করার ফাংশন
  Future<void> _checkDailyStreak() async {
    final result = await EngagementService.checkAndUpdateStreak();

    if (result != null && mounted) {
      if (result['rewardGranted'] == true) {
        _showRewardDialog(result['message']);
      } else if (result['streak'] > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔥 আপনি ${result['streak']} দিন টানা লগইন করেছেন!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ✅ ২. রিওয়ার্ড ডায়ালগ UI
  void _showRewardDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('অভিনন্দন!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content:
            Text(message, style: const TextStyle(fontSize: 15, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ঠিক আছে',
                style: TextStyle(
                    color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMyInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _myUid = uid;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _myName = (data['name'] ?? '').toString();
        _myPhoto = (data['photoUrl'] ?? data['photo'] ?? '').toString();
        _myProfileData = data;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: primaryMaroon,
              onRefresh: _loadMyInfo,
              // ✅ ওয়েবের জন্য কন্টেন্ট সেন্টার করা হলো
              child: kIsWeb
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: 1200), // ওয়েবে সর্বোচ্চ ১২০০ পিক্সেল
                        child: _buildMainSlivers(bn),
                      ),
                    )
                  : _buildMainSlivers(bn),
            ),
          ),
          // ✅ ওয়েবে অ্যাড দেখাবে না, শুধু মোবাইলে দেখাবে
          if (!kIsWeb)
            const BannerAdWidget(placementId: AdConfig.placementHome),
        ],
      ),
    );
  }

  // ✅ মূল কন্টেন্ট (কোড ডুপ্লিকেট এড়াতে আলাদা মেথড)
  Widget _buildMainSlivers(bool bn) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _buildTopBar(bn),
        SliverToBoxAdapter(
          child: ProfileCompletenessCard(
            profile: _myProfileData,
            isBangla: bn,
            maxPendingShown: 2,
            onEditTap: () {
              _navigateDeferred(
                edit_profile_lib.loadLibrary(),
                () => edit_profile_lib.EditProfileScreen(
                  isBangla: bn,
                  profile: UserProfile.fromMap(_myProfileData ?? {},
                      docId: _myUid ?? ''),
                ),
              ).then((_) => _loadMyInfo());
            },
          ),
        ),
        SliverToBoxAdapter(
          child: StoriesRow(
              isBangla: bn, myName: _myName ?? '', myPhoto: _myPhoto ?? ''),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists)
                return const SizedBox();
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final int streak = (data['loginStreak'] ?? 0) as int;
              if (streak == 0) return const SizedBox();
              return StreakCard(streak: streak, isBangla: bn);
            },
          ),
        ),
        SliverToBoxAdapter(child: _buildHeroBanner(bn)),
        SliverToBoxAdapter(child: _buildQuickActions(bn)),
        SliverToBoxAdapter(child: _buildFeaturedSection(bn)),
        SliverToBoxAdapter(child: _buildDistrictSection(bn)),
        SliverToBoxAdapter(child: _buildNewMatchesSection(bn)),
        SliverToBoxAdapter(child: _buildRecentlyJoined(bn)),
        SliverToBoxAdapter(child: _buildSuccessStories(bn)),
        SliverToBoxAdapter(child: _buildPremiumBanner(bn)),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  // ============================================================
  // 1. TOP BAR
  // ============================================================
  Widget _buildTopBar(bool bn) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryGold, width: 1.5),
            ),
            child: ClipOval(
              child: _myPhoto != null && _myPhoto!.isNotEmpty
                  ? AppNetworkImage(
                      _myPhoto!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: lightMaroon),
                      errorWidget: (_, __, ___) => const Icon(Icons.person,
                          color: primaryMaroon, size: 20),
                    )
                  : const Icon(Icons.person, color: primaryMaroon, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bn ? 'স্বাগতম 👋' : 'Welcome 👋',
                  style: const TextStyle(
                      fontSize: 11,
                      color: secondaryText,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  _myName != null && _myName!.isNotEmpty
                      ? _myName!
                      : (bn ? 'Guest' : 'Guest'),
                  style: const TextStyle(
                      fontSize: 15,
                      color: deepMaroon,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ChatIconButton(isBangla: bn),
        NotificationBell(isBangla: bn),
        const SizedBox(width: 6),
      ],
    );
  }

  // ============================================================
  // 2. HERO BANNER
  // ============================================================
  Widget _buildHeroBanner(bool bn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8B1E3F), Color(0xFF5E1128)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryGold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryGold.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: primaryGold, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    bn ? 'বিশ্বস্ত ম্যাট্রিমনি' : 'Trusted Matrimony',
                    style: const TextStyle(
                        color: primaryGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bn
                  ? 'জীবনসাথী খুঁজুন\nসহজে ও নিরাপদে'
                  : 'Find Your\nLife Partner',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(
              bn
                  ? 'হাজারো ভেরিফাইড প্রোফাইল থেকে পছন্দের মানুষ'
                  : 'Search from thousands of verified profiles',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _navigateTo(DiscoverTab(isBangla: bn)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: primaryMaroon, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bn
                            ? 'নাম, জেলা, পেশা...'
                            : 'Name, district, profession...',
                        style:
                            const TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [primaryGold, primaryMaroon]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bn ? 'খুঁজুন' : 'Search',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 3. QUICK ACTIONS
  // ============================================================
  Widget _buildQuickActions(bool bn) {
    final actions = [
      {
        'icon': Icons.person_search,
        'label': bn ? 'খুঁজুন' : 'Search',
        'color': const Color(0xFF9C27B0),
        'onTap': () => _navigateTo(DiscoverTab(isBangla: bn))
      },
      {
        'icon': Icons.location_on,
        'label': bn ? 'নিকটবর্তী' : 'Nearby',
        'color': const Color(0xFF2196F3),
        'onTap': () => _navigateTo(NearbyTab(isBangla: bn))
      },
      {
        'icon': Icons.favorite,
        'label': bn ? 'পছন্দ' : 'Likes',
        'color': const Color(0xFFE91E63),
        'onTap': () => _navigateDeferred(
              who_liked_me_lib.loadLibrary(),
              () => who_liked_me_lib.WhoLikedMeScreen(isBangla: bn),
            )
      },
      {
        'icon': Icons.bookmark,
        'label': bn ? 'শর্টলিস্ট' : 'Shortlist',
        'color': const Color(0xFFFF9800),
        'onTap': () => _navigateDeferred(
              shortlist_lib.loadLibrary(),
              () => shortlist_lib.ShortlistScreen(isBangla: bn),
            )
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: primaryMaroon.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((a) {
          return Expanded(
            child: GestureDetector(
              onTap: a['onTap'] as VoidCallback,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (a['color'] as Color).withValues(alpha: 0.12)),
                    child: Icon(a['icon'] as IconData,
                        color: a['color'] as Color, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(a['label'] as String,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mainText)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // 4. FEATURED PROFILES
  // ============================================================
  Widget _buildFeaturedSection(bool bn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          bn ? 'ফিচারড প্রোফাইল' : 'Featured Profiles',
          bn ? 'বুস্ট করা প্রোফাইল' : 'Boosted profiles',
          onSeeAll: () => _navigateTo(DiscoverTab(isBangla: bn)),
        ),
        SizedBox(
          height: 250,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('boostedUntil', isGreaterThan: Timestamp.now())
                .limit(10)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty)
                return _buildEmptyFeatured(bn);

              final users = snap.data!.docs
                  .where((d) => d.id != _myUid)
                  .map((d) => UserProfile.fromMap(
                      d.data() as Map<String, dynamic>,
                      docId: d.id))
                  .toList();

              if (users.isEmpty) return _buildEmptyFeatured(bn);

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (_, i) => _buildFeaturedCard(users[i], bn),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFeatured(bool bn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline,
                size: 40, color: primaryMaroon.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
                bn
                    ? 'এখনো কোনো ফিচারড প্রোফাইল নেই'
                    : 'No featured profiles yet',
                style: const TextStyle(fontSize: 12, color: secondaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(UserProfile user, bool bn) {
    return GestureDetector(
      onTap: () => _openProfile(user),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              user.photoUrl.isNotEmpty
                  ? AppNetworkImage(
                      user.photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: lightMaroon),
                      errorWidget: (_, __, ___) => Container(
                          color: lightMaroon,
                          child: const Icon(Icons.person,
                              size: 60, color: primaryMaroon)),
                    )
                  : Container(
                      color: lightMaroon,
                      child: const Icon(Icons.person,
                          size: 60, color: primaryMaroon)),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75)
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [primaryGold, primaryMaroon]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text('Boost',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty
                          ? (bn ? 'নাম নেই' : 'No name')
                          : user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (user.age.isNotEmpty) ...[
                          Text('${user.age} ${bn ? "বছর" : "yrs"}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11)),
                          const SizedBox(width: 6),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.6))),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            user.district.isEmpty ? '—' : user.district,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 5. BROWSE BY DISTRICT (✅ Web Layout Added)
  // ============================================================
  Widget _buildDistrictSection(bool bn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          bn ? 'জেলা অনুযায়ী খুঁজুন' : 'Browse by District',
          bn ? '৬৪টি জেলা থেকে পছন্দের প্রোফাইল' : 'All 64 districts',
          onSeeAll: () => _showAllDistricts(bn),
        ),

        // ✅ ওয়েবের জন্য Wrap ব্যবহার করা হলো (একাধিক লাইনে জেলা দেখাবে)
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: bdDistricts
                  .take(10)
                  .map((d) => _buildDistrictCard(d, bn))
                  .toList(),
            ),
          )
        // মোবাইলের জন্য আগের হরাইজন্টাল লিস্ট
        else
          SizedBox(
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: bdDistricts.length > 10 ? 10 : bdDistricts.length,
              itemBuilder: (_, i) {
                final d = bdDistricts[i];
                return _buildDistrictCard(d, bn);
              },
            ),
          ),

        const SizedBox(height: 12),

        // সব জেলা দেখার বাটন
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => _showAllDistricts(bn),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: primaryMaroon.withValues(alpha: 0.25), width: 1.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.grid_view, color: primaryMaroon, size: 18),
                  const SizedBox(width: 8),
                  Text(bn ? 'সব ৬৪টি জেলা দেখুন' : 'See all 64 districts',
                      style: const TextStyle(
                          color: primaryMaroon,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward,
                      color: primaryMaroon, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistrictCard(String district, bool bn) {
    return GestureDetector(
      onTap: () => _openDistrictUsers(district),
      child: Container(
        width: 110,
        margin: kIsWeb
            ? EdgeInsets.zero
            : const EdgeInsets.only(right: 10), // ওয়েবে মার্জিন লাগবে না
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryMaroon.withValues(alpha: 0.08),
              primaryGold.withValues(alpha: 0.06)
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryMaroon.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryMaroon.withValues(alpha: 0.15)),
              child:
                  const Icon(Icons.location_on, size: 14, color: primaryMaroon),
            ),
            const SizedBox(height: 6),
            Text(district,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(bn ? 'প্রোফাইল দেখুন' : 'View profiles',
                style: const TextStyle(fontSize: 9.5, color: secondaryText)),
          ],
        ),
      ),
    );
  }

  void _showAllDistricts(bool bn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllDistrictsSheet(
        isBangla: bn,
        onSelect: (district) {
          Navigator.pop(context);
          _openDistrictUsers(district);
        },
      ),
    );
  }

  void _openDistrictUsers(String district) {
    _navigateDeferred(
      district_users_lib.loadLibrary(),
      () => district_users_lib.DistrictUsersScreen(
        isBangla: widget.isBangla,
        district: district,
      ),
    );
  }

  // ============================================================
  // 6. NEW MATCHES
  // ============================================================
  Widget _buildNewMatchesSection(bool bn) {
    if (_myUid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          bn ? 'নতুন ম্যাচ' : 'New Matches',
          bn ? 'আপনার সাথে match হয়েছে' : 'You matched with them',
          onSeeAll: () => _navigateTo(MatchesTab(isBangla: bn)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .where('users', arrayContains: _myUid)
              .limit(10)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 100,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: primaryMaroon, strokeWidth: 2)));
            }

            if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) {
              return _buildEmptyMatches(bn);
            }

            final matchDocs = snap.data!.docs;
            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: matchDocs.length,
                itemBuilder: (_, i) {
                  final data = matchDocs[i].data() as Map<String, dynamic>;
                  final users = List<String>.from(data['users'] ?? const []);
                  final otherUid =
                      users.firstWhere((u) => u != _myUid, orElse: () => '');
                  if (otherUid.isEmpty) return const SizedBox.shrink();

                  final u1 = data['user1'] as Map<String, dynamic>?;
                  final u2 = data['user2'] as Map<String, dynamic>?;
                  final other = (u1?['uid'] == otherUid) ? u1 : u2;
                  if (other == null) return const SizedBox.shrink();

                  return _buildMatchAvatarFromMap(other, bn);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMatchAvatarFromMap(Map<String, dynamic> user, bool bn) {
    final name = (user['name'] ?? '').toString();
    final photoUrl = (user['photoUrl'] ?? '').toString();
    final uid = (user['uid'] ?? '').toString();

    return GestureDetector(
      onTap: () => _openProfileByUid(uid),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      LinearGradient(colors: [primaryGold, primaryMaroon])),
              child: Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? AppNetworkImage(
                          photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: lightMaroon),
                          errorWidget: (_, __, ___) => Container(
                              color: lightMaroon,
                              child: const Icon(Icons.person,
                                  color: primaryMaroon, size: 28)),
                        )
                      : Container(
                          color: lightMaroon,
                          child: const Icon(Icons.person,
                              color: primaryMaroon, size: 28)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                name.isEmpty ? '—' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: mainText, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProfileByUid(String uid) async {
    if (uid.isEmpty) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || !mounted) return;
      final user = UserProfile.fromMap(
          doc.data() as Map<String, dynamic>? ?? {},
          docId: uid);

      _navigateDeferred(
        user_profile_view_lib.loadLibrary(),
        () => user_profile_view_lib.UserProfileViewScreen(
          isBangla: widget.isBangla,
          user: user,
        ),
      );
    } catch (e) {
      debugPrint('❌ _openProfileByUid error: $e');
    }
  }

  Widget _buildEmptyMatches(bool bn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryMaroon.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border, color: primaryMaroon, size: 20),
              const SizedBox(width: 8),
              Text(
                  bn
                      ? 'এখনো কোনো ম্যাচ নেই — Like করুন!'
                      : 'No matches yet — Start liking!',
                  style: const TextStyle(fontSize: 12, color: secondaryText)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 7. RECENTLY JOINED (✅ Web Layout Added)
  // ============================================================
  Widget _buildRecentlyJoined(bool bn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          bn ? 'সম্প্রতি যোগদান করেছেন' : 'Recently Joined',
          bn ? 'নতুন সদস্য' : 'New members',
          onSeeAll: () => _navigateTo(DiscoverTab(isBangla: bn)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty)
              return _buildEmptyRecently(bn);

            final users = snap.data!.docs
                .where((d) => d.id != _myUid)
                .map((d) => UserProfile.fromMap(
                    d.data() as Map<String, dynamic>,
                    docId: d.id))
                .toList();

            if (users.isEmpty) return _buildEmptyRecently(bn);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                // ✅ ওয়েবে ৪ কলাম, মোবাইলে ২ কলাম
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: kIsWeb ? 4 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (_, i) => _buildRecentlyCard(users[i], bn),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyRecently(bool bn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Text(bn ? 'এখনো কোনো সদস্য নেই' : 'No members yet',
            style: const TextStyle(color: secondaryText, fontSize: 12)),
      ),
    );
  }

  Widget _buildRecentlyCard(UserProfile user, bool bn) {
    return GestureDetector(
      onTap: () => _openProfile(user),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: user.photoUrl.isNotEmpty
                    ? AppNetworkImage(
                        user.photoUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(color: lightMaroon),
                        errorWidget: (_, __, ___) => Container(
                            color: lightMaroon,
                            child: const Icon(Icons.person,
                                size: 40, color: primaryMaroon)),
                      )
                    : Container(
                        color: lightMaroon,
                        child: const Icon(Icons.person,
                            size: 40, color: primaryMaroon)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isEmpty ? '—' : user.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: mainText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (user.age.isNotEmpty) ...[
                        Text('${user.age} ${bn ? "বছর" : "yrs"}',
                            style: const TextStyle(
                                fontSize: 10.5, color: secondaryText)),
                        const SizedBox(width: 4),
                        if (user.district.isNotEmpty)
                          Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: secondaryText)),
                        const SizedBox(width: 4),
                      ],
                      if (user.district.isNotEmpty)
                        Expanded(
                          child: Text(user.district,
                              style: const TextStyle(
                                  fontSize: 10.5, color: secondaryText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 8. SUCCESS STORIES
  // ============================================================
  Widget _buildSuccessStories(bool bn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<int>(
          stream: SuccessStoryService.streamCount(),
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bn ? 'সফলতার গল্প' : 'Success Stories',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: deepMaroon)),
                        const SizedBox(height: 2),
                        Text(
                          count > 0
                              ? (bn
                                  ? '$count টি সফল জুটি'
                                  : '$count happy couples')
                              : (bn ? 'তাদের জীবনের গল্প' : 'Happy couples'),
                          style: const TextStyle(
                              fontSize: 11, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _navigateDeferred(
                      submit_story_lib.loadLibrary(),
                      () => submit_story_lib.SubmitStoryScreen(isBangla: bn),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [primaryGold, primaryMaroon]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: primaryMaroon.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(bn ? 'গল্প যোগ করুন' : 'Add Story',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        StreamBuilder<List<SuccessStory>>(
          stream: SuccessStoryService.streamApproved(limit: 10),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return _buildStoriesLoading();
            if (snap.hasError) return _buildStoriesEmpty(bn);

            final stories = snap.data ?? [];
            if (stories.isEmpty) return _buildStoriesEmpty(bn);

            return SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: stories.length,
                itemBuilder: (_, i) => _buildStoryCard(stories[i], bn),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStoryCard(SuccessStory story, bool bn) {
    return GestureDetector(
      onTap: () => _openStoryDetails(story, bn),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: primaryMaroon.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
          border: Border.all(color: primaryMaroon.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (story.hasPhotos)
              Container(
                height: 110,
                decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      story.primaryPhoto,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: lightMaroon),
                      errorWidget: (_, __, ___) => Container(
                          color: lightMaroon,
                          child: const Icon(Icons.favorite,
                              color: primaryMaroon, size: 40)),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55)
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (story.photoCount > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library,
                                  color: Colors.white, size: 11),
                              const SizedBox(width: 3),
                              Text('${story.photoCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9)),
                        child: const Icon(Icons.favorite,
                            color: primaryMaroon, size: 14),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Text(
                        story.coupleNames,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    primaryMaroon.withValues(alpha: 0.08),
                    primaryGold.withValues(alpha: 0.05)
                  ]),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryMaroon.withValues(alpha: 0.1)),
                      child: const Icon(Icons.favorite,
                          color: primaryMaroon, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        story.coupleNames,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  if (story.district.isNotEmpty) ...[
                    const Icon(Icons.location_on,
                        size: 11, color: secondaryText),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(story.district,
                          style: const TextStyle(
                              fontSize: 10.5, color: secondaryText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ] else
                    const Spacer(),
                  if (story.marriageDate != null)
                    Text(story.timeAgo(bn),
                        style: const TextStyle(
                            fontSize: 10,
                            color: secondaryText,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Text(
                  '"${story.story}"',
                  style: const TextStyle(
                      fontSize: 12,
                      color: secondaryText,
                      height: 1.4,
                      fontStyle: FontStyle.italic),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: primaryMaroon.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified,
                            color: primaryMaroon, size: 11),
                        const SizedBox(width: 3),
                        Text(bn ? 'ভেরিফাইড' : 'Verified',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryMaroon)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (story.hasPhotos)
                    Row(
                      children: [
                        Text(bn ? 'ছবি দেখুন' : 'View photos',
                            style: const TextStyle(
                                fontSize: 10,
                                color: primaryMaroon,
                                fontWeight: FontWeight.w600)),
                        const Icon(Icons.chevron_right,
                            size: 14, color: primaryMaroon),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoriesLoading() {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 2,
        itemBuilder: (_, __) => Container(
          width: 280,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryMaroon.withValues(alpha: 0.08)),
          ),
          child: const Center(
              child: CircularProgressIndicator(
                  color: primaryMaroon, strokeWidth: 2)),
        ),
      ),
    );
  }

  Widget _buildStoriesEmpty(bool bn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryMaroon.withValues(alpha: 0.08)),
            child: const Icon(Icons.favorite_border,
                color: primaryMaroon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bn ? 'এখনো কোনো সফল গল্প নেই' : 'No success stories yet',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: mainText)),
                const SizedBox(height: 3),
                Text(
                    bn
                        ? 'শীঘ্রই আসছে — আপনিও পারেন গল্পের অংশ হতে'
                        : 'Coming soon — you could be next!',
                    style: const TextStyle(fontSize: 11, color: secondaryText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openStoryDetails(SuccessStory story, bool bn) {
    _navigateDeferred(
      story_details_lib.loadLibrary(),
      () => story_details_lib.StoryDetailsScreen(
        story: story,
        isBangla: bn,
      ),
    );
  }

  // ============================================================
  // 9. PREMIUM BANNER
  // ============================================================
  Widget _buildPremiumBanner(bool bn) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFE6A500)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: primaryGold.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.25)),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bn ? 'প্রিমিয়াম মেম্বার হোন' : 'Go Premium',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                    bn
                        ? 'সব প্রোফাইল দেখুন · Limited offer'
                        : 'See all profiles · Limited offer',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(bn ? 'বিস্তারিত' : 'View',
                style: const TextStyle(
                    color: primaryMaroon,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  Widget _buildSectionHeader(String title, String subtitle,
      {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: deepMaroon)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11, color: secondaryText)),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(widget.isBangla ? 'সব' : 'See all',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryMaroon)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right,
                      size: 16, color: primaryMaroon),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openProfile(UserProfile user) {
    _navigateDeferred(
      user_profile_view_lib.loadLibrary(),
      () => user_profile_view_lib.UserProfileViewScreen(
        isBangla: widget.isBangla,
        user: user,
      ),
    );
  }
}

// ============================================================
// ALL DISTRICTS BOTTOM SHEET
// ============================================================
class _AllDistrictsSheet extends StatefulWidget {
  final bool isBangla;
  final Function(String district) onSelect;

  const _AllDistrictsSheet({required this.isBangla, required this.onSelect});

  @override
  State<_AllDistrictsSheet> createState() => _AllDistrictsSheetState();
}

class _AllDistrictsSheetState extends State<_AllDistrictsSheet> {
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_city,
                        color: primaryMaroon, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bn ? 'সব ৬৪টি জেলা' : 'All 64 Districts',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: lightMaroon,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('${bdDistricts.length}',
                          style: const TextStyle(
                              color: primaryMaroon,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: bn ? 'জেলা খুঁজুন...' : 'Search district...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search,
                        color: primaryMaroon, size: 20),
                    filled: true,
                    fillColor: warmWhite,
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
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                            bn
                                ? 'কোনো জেলা পাওয়া যায়নি'
                                : 'No district found',
                            style: const TextStyle(color: secondaryText)))
                    : GridView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        // ✅ ওয়েবে ৪ কলাম, মোবাইলে ২ কলাম
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kIsWeb ? 4 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final d = list[i];
                          return GestureDetector(
                            onTap: () => widget.onSelect(d),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: warmWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        primaryMaroon.withValues(alpha: 0.15),
                                    width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryMaroon.withValues(
                                            alpha: 0.12)),
                                    child: const Icon(Icons.location_on,
                                        color: primaryMaroon, size: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: mainText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
