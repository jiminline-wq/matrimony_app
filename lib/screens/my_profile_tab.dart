import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/like_service.dart';
import '../utils/boost_service.dart';
import '../utils/shortlist_service.dart';
import '../widgets/deactivate_dialog.dart';
import '../services/fcm_service.dart';
import '../utils/test_data_loader.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../widgets/profile_completeness_card.dart';

// ✅ Deferred Loading Imports
import 'edit_profile_screen.dart' deferred as edit_profile_lib;
import 'welcome_screen.dart' deferred as welcome_lib;
import 'who_viewed_me_screen.dart' deferred as who_viewed_me_lib;
import 'who_liked_me_screen.dart' deferred as who_liked_me_lib;
import 'shortlist_screen.dart' deferred as shortlist_lib;
import 'referral_screen.dart' deferred as referral_lib;
import 'boost_screen.dart' deferred as boost_lib;

// ============================================================
// MY PROFILE TAB
// ============================================================

class MyProfileTab extends StatefulWidget {
  final bool isBangla;

  const MyProfileTab({super.key, required this.isBangla});

  @override
  State<MyProfileTab> createState() => _MyProfileTabState();
}

class _MyProfileTabState extends State<MyProfileTab> {
  UserProfile? profile;
  bool isLoading = true;
  String? errorMessage;
  int viewerCount = 0;
  int likeCount = 0;
  int shortlistCount = 0;
  int _currentPhotoIndex = 0;
  bool _isBoosting = false;

  // ✅ ওয়েবের জন্য PageController
  final PageController _headerPageController = PageController();

  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    loadProfile();
    loadViewerCount();
    loadLikeCount();
    loadShortlistCount();
  }

  @override
  void dispose() {
    if (kIsWeb) _headerPageController.dispose();
    super.dispose();
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
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screenBuilder()),
      );
    }
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
        errorMessage =
            widget.isBangla ? 'আপনি লগইন করা নেই।' : 'You are not logged in.';
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          isLoading = false;
          errorMessage = widget.isBangla
              ? 'আপনার প্রোফাইল তথ্য পাওয়া যায়নি।'
              : 'Profile data not found.';
        });
        return;
      }

      setState(() {
        profile = UserProfile.fromMap(doc.data()!, docId: doc.id);
        _profileData = doc.data();
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            widget.isBangla ? 'তথ্য লোড করা যায়নি।' : 'Could not load data.';
      });
    }
  }

  Future<void> loadViewerCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('profileViews')
          .doc(user.uid)
          .collection('viewers')
          .get();
      if (mounted) setState(() => viewerCount = snapshot.docs.length);
    } catch (e) {}
  }

  Future<void> loadLikeCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final count = await LikeService.getLikesCount(user.uid);
    if (mounted) setState(() => likeCount = count);
  }

  Future<void> loadShortlistCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final count = await ShortlistService.getSavedCount(user.uid);
    if (mounted) setState(() => shortlistCount = count);
  }

  Future<void> _logout() async {
    await FcmService.removeToken();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await welcome_lib.loadLibrary();

    if (!mounted) return;
    Navigator.pop(context);

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => welcome_lib.WelcomeScreen()),
        (route) => false);
  }

  Future<void> _deactivateAccount() async {
    final confirmed =
        await DeactivateDialog.show(context, isBangla: widget.isBangla);
    if (confirmed != true) return;
    await FcmService.removeToken();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await welcome_lib.loadLibrary();

    if (!mounted) return;
    Navigator.pop(context);

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => welcome_lib.WelcomeScreen()),
        (route) => false);
  }

  Future<void> _openWhoViewedMe() async {
    await _navigateDeferred(
      who_viewed_me_lib.loadLibrary(),
      () => who_viewed_me_lib.WhoViewedMeScreen(isBangla: widget.isBangla),
    );
    loadViewerCount();
  }

  Future<void> _openWhoLikedMe() async {
    await _navigateDeferred(
      who_liked_me_lib.loadLibrary(),
      () => who_liked_me_lib.WhoLikedMeScreen(isBangla: widget.isBangla),
    );
    loadLikeCount();
  }

  Future<void> _openShortlist() async {
    await _navigateDeferred(
      shortlist_lib.loadLibrary(),
      () => shortlist_lib.ShortlistScreen(isBangla: widget.isBangla),
    );
    loadShortlistCount();
  }

  Future<void> _openEditProfile() async {
    if (profile == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      ),
    );

    await edit_profile_lib.loadLibrary();

    if (!mounted) return;
    Navigator.pop(context);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => edit_profile_lib.EditProfileScreen(
          isBangla: widget.isBangla,
          profile: profile!,
        ),
      ),
    );

    if (result == true) loadProfile();
  }

  // ============================================================
  // BUILD (Responsive Layout Switcher)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: warmWhite,
          appBar: AppBar(
            backgroundColor: warmWhite,
            elevation: 0,
            centerTitle: isDesktop,
            automaticallyImplyLeading: false,
            title: Text(bn ? 'আমার প্রোফাইল' : 'My Profile',
                style: const TextStyle(
                    color: deepMaroon, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: deepMaroon),
            actions: [
              ChatIconButton(isBangla: bn),
              NotificationBell(isBangla: bn),
              IconButton(
                  icon: const Icon(Icons.bug_report, color: primaryMaroon),
                  tooltip: bn ? 'Test Users' : 'Test Users',
                  onPressed: () => _showTestDataDialog(bn)),
              IconButton(
                  icon: const Icon(Icons.logout, color: deepMaroon),
                  tooltip: bn ? 'লগআউট' : 'Logout',
                  onPressed: _logout),
            ],
          ),
          body: _buildBody(bn, isDesktop),
        );
      },
    );
  }

  Widget _buildBody(bool bn, bool isDesktop) {
    if (isLoading)
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));

    if (errorMessage != null) {
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
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  loadProfile();
                  loadViewerCount();
                  loadLikeCount();
                  loadShortlistCount();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white),
                child: Text(bn ? 'আবার চেষ্টা করুন' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final bool isBoostActive =
        BoostService.isBoostActive(profile!.boostedUntil);

    if (isDesktop) {
      return _buildWebLayout(bn, isBoostActive);
    } else {
      return _buildMobileLayout(bn, isBoostActive);
    }
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn, bool isBoostActive) {
    return RefreshIndicator(
      onRefresh: () async {
        await loadProfile();
        await loadViewerCount();
        await loadLikeCount();
        await loadShortlistCount();
      },
      color: primaryMaroon,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          ProfileCompletenessCard(
            profile: _profileData,
            isBangla: bn,
            onEditTap: _openEditProfile,
          ),
          _buildProfileHeader(bn, isBoostActive, 595),
          const SizedBox(height: 20),

          _buildSection(
            title: bn ? "যোগাযোগ" : "Contact",
            icon: Icons.contact_mail_outlined,
            rows: [
              _row(
                  bn ? "ইমেইল" : "Email", profile!.email, Icons.email_outlined),
              _row(bn ? "ফোন" : "Phone", profile!.phone, Icons.phone_outlined),
            ],
          ),
          _buildSection(
            title: bn ? "মৌলিক তথ্য" : "Basic Information",
            icon: Icons.person_outline,
            rows: [
              _row(bn ? "লিঙ্গ" : "Gender", profile!.gender, Icons.wc),
              _row(bn ? "ধর্ম" : "Religion", profile!.religion,
                  Icons.auto_awesome_outlined),
              _row(bn ? "জেলা" : "District", profile!.district,
                  Icons.location_on_outlined),
              _row(bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                  profile!.maritalStatus, Icons.favorite_border),
              _row(bn ? "উচ্চতা" : "Height", profile!.height, Icons.height),
              _row(bn ? "গায়ের রং" : "Skin Tone", profile!.skinTone,
                  Icons.color_lens_outlined),
            ],
          ),
          _buildSection(
            title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
            icon: Icons.school_outlined,
            rows: [
              _row(bn ? "শিক্ষা" : "Education", profile!.education,
                  Icons.school_outlined),
              _row(bn ? "পেশা" : "Profession", profile!.profession,
                  Icons.work_outline),
            ],
          ),
          if (profile!.aboutMe.isNotEmpty)
            _buildSection(
              title: bn ? "নিজের সম্পর্কে" : "About Me",
              icon: Icons.favorite_outline,
              rows: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(profile!.aboutMe,
                      style: const TextStyle(
                          fontSize: 14, height: 1.6, color: mainText)),
                ),
              ],
            ),
          _buildSection(
            title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
            icon: Icons.favorite,
            rows: [
              _row(bn ? "পছন্দের বয়স" : "Preferred Age", profile!.preferredAge,
                  Icons.cake_outlined),
              _row(bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                  profile!.preferredReligion, Icons.auto_awesome_outlined),
              _row(bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                  profile!.preferredEducation, Icons.school_outlined),
              _row(bn ? "পছন্দের পেশা" : "Preferred Profession",
                  profile!.preferredProfession, Icons.work_outline),
            ],
          ),
          _buildReferralCard(bn),
          _buildDangerZone(bn),

          const SizedBox(height: 8),
          // ✅ AdMob শুধু মোবাইলে
          if (!kIsWeb)
            const BannerAdWidget(placementId: AdConfig.placementMyProfile),
        ],
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম ড্যাশবোর্ড ডিজাইন)
  // ============================================================
  Widget _buildWebLayout(bool bn, bool isBoostActive) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔴 বাম কলাম (Profile Image & Actions)
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileCompletenessCard(
                        profile: _profileData,
                        isBangla: bn,
                        onEditTap: _openEditProfile,
                      ),
                      const SizedBox(height: 20),
                      _buildProfileHeader(
                          bn, isBoostActive, 550), // ওয়েবে একটু ছোট হাইট
                    ],
                  ),
                ),

                const SizedBox(width: 30),

                // 🟢 ডান কলাম (Info Sections)
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        title: bn ? "যোগাযোগ" : "Contact",
                        icon: Icons.contact_mail_outlined,
                        rows: [
                          _row(bn ? "ইমেইল" : "Email", profile!.email,
                              Icons.email_outlined),
                          _row(bn ? "ফোন" : "Phone", profile!.phone,
                              Icons.phone_outlined),
                        ],
                      ),
                      _buildSection(
                        title: bn ? "মৌলিক তথ্য" : "Basic Information",
                        icon: Icons.person_outline,
                        rows: [
                          _row(bn ? "লিঙ্গ" : "Gender", profile!.gender,
                              Icons.wc),
                          _row(bn ? "ধর্ম" : "Religion", profile!.religion,
                              Icons.auto_awesome_outlined),
                          _row(bn ? "জেলা" : "District", profile!.district,
                              Icons.location_on_outlined),
                          _row(bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                              profile!.maritalStatus, Icons.favorite_border),
                          _row(bn ? "উচ্চতা" : "Height", profile!.height,
                              Icons.height),
                          _row(bn ? "গায়ের রং" : "Skin Tone",
                              profile!.skinTone, Icons.color_lens_outlined),
                        ],
                      ),
                      _buildSection(
                        title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
                        icon: Icons.school_outlined,
                        rows: [
                          _row(bn ? "শিক্ষা" : "Education", profile!.education,
                              Icons.school_outlined),
                          _row(bn ? "পেশা" : "Profession", profile!.profession,
                              Icons.work_outline),
                        ],
                      ),
                      if (profile!.aboutMe.isNotEmpty)
                        _buildSection(
                          title: bn ? "নিজের সম্পর্কে" : "About Me",
                          icon: Icons.favorite_outline,
                          rows: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(profile!.aboutMe,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: mainText)),
                            ),
                          ],
                        ),
                      _buildSection(
                        title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
                        icon: Icons.favorite,
                        rows: [
                          _row(bn ? "পছন্দের বয়স" : "Preferred Age",
                              profile!.preferredAge, Icons.cake_outlined),
                          _row(
                              bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                              profile!.preferredReligion,
                              Icons.auto_awesome_outlined),
                          _row(
                              bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                              profile!.preferredEducation,
                              Icons.school_outlined),
                          _row(bn ? "পছন্দের পেশা" : "Preferred Profession",
                              profile!.preferredProfession, Icons.work_outline),
                        ],
                      ),
                      _buildReferralCard(bn),
                      _buildDangerZone(bn),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER (Shared by both layouts)
  // ============================================================
  Widget _buildProfileHeader(bool bn, bool isBoostActive, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ১. মূল PageView (সোয়াইপ কাজ করবে)
            if (profile!.photoUrls.isNotEmpty)
              PageView.builder(
                controller: _headerPageController,
                itemCount: profile!.photoUrls.length,
                onPageChanged: (index) =>
                    setState(() => _currentPhotoIndex = index),
                itemBuilder: (context, index) {
                  return AppNetworkImage(
                    profile!.photoUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: lightMaroon,
                        child: const Center(
                            child: Icon(Icons.person,
                                size: 120, color: primaryMaroon))),
                  );
                },
              )
            else
              Container(
                  color: lightMaroon,
                  child: const Center(
                      child:
                          Icon(Icons.person, size: 120, color: primaryMaroon))),

            // ✅ ২. শুধু ওয়েব: ছবির বাম/ডানে ট্যাপ করে ছবি বদলানোর জোন
            // translucent ব্যবহার করা হয়েছে যাতে PageView এর swipe-ও কাজ করে
            if (kIsWeb && profile!.photoUrls.length > 1)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) {
                        if (!_headerPageController.hasClients) return;
                        final currentPage =
                            (_headerPageController.page ?? 0).round();
                        final isLeft =
                            details.localPosition.dx < constraints.maxWidth / 2;
                        if (isLeft) {
                          if (currentPage > 0) {
                            _headerPageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        } else {
                          if (currentPage < profile!.photoUrls.length - 1) {
                            _headerPageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),

            // ৩. গ্রেডিয়েন্ট ওভারলে
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.90)
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),

            // ৪. ইন্ডিকেটর বার
            if (profile!.photoUrls.length > 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(
                    profile!.photoUrls.length,
                    (index) => Expanded(
                      child: kIsWeb
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _headerPageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              },
                              child: Container(
                                height: 3,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                    color: index == _currentPhotoIndex
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                            )
                          : Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                  color: index == _currentPhotoIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                    ),
                  ),
                ),
              ),

            // ৫. ছবি সংখ্যা (2/5)
            if (profile!.photoUrls.length > 1)
              Positioned(
                top: 24,
                right: 12,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        '${_currentPhotoIndex + 1} / ${profile!.photoUrls.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

            // ৬. Boosted ব্যাজ
            if (isBoostActive)
              Positioned(
                top: kIsWeb ? 50 : 12,
                left: 12,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [primaryGold, primaryMaroon]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: primaryMaroon.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Boosted',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))
                    ]),
                  ),
                ),
              ),

            // ৭. নাম, বয়স, বাটন ইত্যাদি
            Positioned(
              left: 20,
              right: 20,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          profile!.name.isEmpty
                              ? (bn ? 'নাম নেই' : 'No name')
                              : profile!.name,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black38, blurRadius: 10)
                              ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile!.age.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1)),
                          child: Text(profile!.age,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                            profile!.district.isEmpty ? '—' : profile!.district,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (profile!.maritalStatus.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(profile!.maritalStatus,
                          style: const TextStyle(
                              color: primaryMaroon,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: isBoostActive
                        ? null
                        : () async {
                            await _navigateDeferred(
                              boost_lib.loadLibrary(),
                              () => boost_lib.BoostScreen(
                                  isBangla: widget.isBangla),
                            );
                            loadProfile();
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isBoostActive
                            ? LinearGradient(colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade600
                              ])
                            : const LinearGradient(
                                colors: [primaryGold, primaryMaroon]),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isBoostActive
                            ? []
                            : [
                                BoxShadow(
                                    color: primaryMaroon.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isBoosting)
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                          else
                            Icon(
                                isBoostActive ? Icons.check_circle : Icons.bolt,
                                color: Colors.white,
                                size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isBoosting
                                ? (bn ? 'Boost হচ্ছে...' : 'Boosting...')
                                : isBoostActive
                                    ? (bn ? 'Boost Active ⚡' : 'Boost Active ⚡')
                                    : (bn
                                        ? 'Profile Boost করুন'
                                        : 'Boost Profile'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _watermarkButton(
                              icon: Icons.edit,
                              label: bn ? 'এডিট' : 'Edit',
                              onTap: _openEditProfile)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _watermarkButton(
                              icon: Icons.favorite,
                              label: bn ? 'Like' : 'Likes',
                              badge: likeCount > 0 ? '$likeCount' : null,
                              onTap: _openWhoLikedMe)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      child: _watermarkButton(
                          icon: Icons.visibility,
                          label: bn ? 'কে দেখেছে' : 'Who Viewed',
                          badge: viewerCount > 0 ? '$viewerCount' : null,
                          onTap: _openWhoViewedMe)),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      child: _watermarkButton(
                          icon: Icons.bookmark,
                          label: bn ? 'সংরক্ষিত প্রোফাইল' : 'Saved Profiles',
                          badge: shortlistCount > 0 ? '$shortlistCount' : null,
                          onTap: _openShortlist)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================
  // REUSABLE WIDGETS
  // ============================================================

  Widget _buildReferralCard(bool bn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [lightGold, lightMaroon]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
              color: primaryGold.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.card_giftcard_rounded,
                color: primaryMaroon, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bn ? 'বন্ধু invite করুন' : 'Invite Friends',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: mainText)),
                const SizedBox(height: 2),
                Text(
                    bn
                        ? 'প্রতিটা বন্ধু থেকে 24h boost ⚡'
                        : 'Get 24h boost per friend ⚡',
                    style: const TextStyle(fontSize: 12, color: secondaryText)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateDeferred(
              referral_lib.loadLibrary(),
              () => referral_lib.ReferralScreen(isBangla: widget.isBangla),
            ),
            child: Text(bn ? 'দেখুন' : 'View',
                style: const TextStyle(
                    color: primaryMaroon, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool bn) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.settings_outlined,
                    color: Colors.orange.shade700, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(bn ? 'অ্যাকাউন্ট সেটিংস' : 'Account Settings',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainText))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bn
                ? 'Deactivate করলে আপনার প্রোফাইল Discover, Nearby এবং Matches থেকে লুকিয়ে যাবে। সব তথ্য সুরক্ষিত থাকবে — যেকোনো সময় আবার ফিরে আসতে পারবেন।'
                : 'Deactivating will hide your profile from Discover, Nearby and Matches. All data will be saved — you can come back anytime.',
            style: const TextStyle(
                fontSize: 12, color: secondaryText, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _deactivateAccount,
              icon:
                  const Icon(Icons.pause_circle_outline, color: Colors.orange),
              label: Text(bn ? 'Account Deactivate করুন' : 'Deactivate Account',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.orange.shade300, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _watermarkButton(
      {required IconData icon,
      required String label,
      String? badge,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: lightMaroon, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: primaryMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: secondaryText)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Not specified' : value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: mainText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title,
      required IconData icon,
      required List<Widget> rows}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: lightGold, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: deepGold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainText))),
            ],
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  void _showTestDataDialog(bool bn) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              const Text('Test Data',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            bn
                ? '১৫টা test user তৈরি হবে। এটা শুধু development-এর জন্য।\n\nপরে অবশ্যই এই button মুছে ফেলবেন।'
                : '১৫ test users will be created. Only for development.\n\nRemember to remove this button later.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(bn ? 'বাতিল' : 'Cancel',
                    style: const TextStyle(color: secondaryText))),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _loadTestData(bn);
              },
              child: Text(bn ? 'তৈরি করুন' : 'Create',
                  style: const TextStyle(
                      color: primaryMaroon, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteTestData(bn);
              },
              child: Text(bn ? 'মুছে ফেলুন' : 'Delete',
                  style: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadTestData(bool bn) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: primaryMaroon)));
    final count = await TestDataLoader.loadTestUsers();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text(bn
              ? '$count টা test user তৈরি হয়েছে ✅'
              : '$count test users created ✅')
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _deleteTestData(bool bn) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: primaryMaroon)));
    final count = await TestDataLoader.deleteTestUsers();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.delete, color: Colors.white),
          const SizedBox(width: 10),
          Text(bn
              ? '$count টা test user মুছে ফেলা হয়েছে'
              : '$count test users deleted')
        ]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
