import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ kIsWeb এর জন্য
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/block_report_service.dart';
import '../utils/boost_service.dart';
import '../utils/shortlist_service.dart';
import '../utils/like_service.dart';
import '../widgets/report_dialog.dart';
import '../widgets/verified_badge.dart';

// ============================================================
// USER PROFILE VIEW SCREEN (অন্য user-এর profile)
// ============================================================

class UserProfileViewScreen extends StatefulWidget {
  final bool isBangla;
  final UserProfile user;

  const UserProfileViewScreen({
    super.key,
    required this.isBangla,
    required this.user,
  });

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  bool _isBlocked = false;
  bool _isSaved = false;
  bool _isLiked = false;
  bool _isLiking = false;
  int _currentPhotoIndex = 0;

  // ✅ ওয়েবের জন্য PageController
  final PageController _headerPageController = PageController();

  @override
  void initState() {
    super.initState();
    _recordView();
    _checkBlockedStatus();
    _checkSavedStatus();
    _checkLikeStatus();
  }

  @override
  void dispose() {
    if (kIsWeb) _headerPageController.dispose();
    super.dispose();
  }

  Future<void> _recordView() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    if (me.uid == widget.user.uid) return;

    try {
      await FirebaseFirestore.instance
          .collection('profileViews')
          .doc(widget.user.uid)
          .collection('viewers')
          .doc(me.uid)
          .set({'viewerUid': me.uid, 'viewedAt': FieldValue.serverTimestamp()});
    } catch (e) {}
  }

  Future<void> _checkBlockedStatus() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final blocked = await BlockReportService.isBlocked(
        myUid: me.uid, theirUid: widget.user.uid);
    if (mounted) setState(() => _isBlocked = blocked);
  }

  Future<void> _checkSavedStatus() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    if (me.uid == widget.user.uid) return;
    final saved = await ShortlistService.isSaved(
        myUid: me.uid, theirUid: widget.user.uid);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _checkLikeStatus() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    if (me.uid == widget.user.uid) return;
    final liked =
        await LikeService.haveILiked(myUid: me.uid, theirUid: widget.user.uid);
    if (mounted) setState(() => _isLiked = liked);
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final bn = widget.isBangla;

    setState(() => _isLiking = true);
    bool success;
    if (_isLiked) {
      success = await LikeService.unlikeUser(
          myUid: me.uid, theirUid: widget.user.uid);
    } else {
      success =
          await LikeService.likeUser(myUid: me.uid, theirUid: widget.user.uid);
    }

    if (!mounted) return;
    setState(() {
      _isLiking = false;
      if (success) _isLiked = !_isLiked;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isLiked
                      ? (bn
                          ? '${widget.user.name}-কে Like করা হয়েছে ❤️'
                          : 'Liked ${widget.user.name} ❤️')
                      : (bn ? 'Like সরানো হয়েছে' : 'Like removed'),
                ),
              ),
            ],
          ),
          backgroundColor:
              _isLiked ? Colors.pink.shade600 : Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bn
              ? 'কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।'
              : 'Something went wrong. Please try again.'),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleShortlist() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final bn = widget.isBangla;
    bool success;

    if (_isSaved) {
      success = await ShortlistService.removeUser(
          myUid: me.uid, theirUid: widget.user.uid);
    } else {
      success = await ShortlistService.saveUser(
          myUid: me.uid, theirUid: widget.user.uid);
    }

    if (!mounted) return;
    if (success) {
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isSaved
                      ? (bn
                          ? '${widget.user.name}-কে shortlist-এ save করা হয়েছে'
                          : 'Saved ${widget.user.name} to shortlist')
                      : (bn
                          ? '${widget.user.name}-কে shortlist থেকে সরানো হয়েছে'
                          : 'Removed ${widget.user.name} from shortlist'),
                ),
              ),
            ],
          ),
          backgroundColor: _isSaved ? primaryMaroon : Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bn
              ? 'কিছু সমস্যা হয়েছে। আবার চেষ্টা করুন।'
              : 'Something went wrong. Please try again.'),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleBlockAction(bool bn) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _isBlocked
                ? (bn ? 'আনব্লক করবেন?' : 'Unblock?')
                : (bn ? 'ব্লক করবেন?' : 'Block?'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            _isBlocked
                ? (bn
                    ? 'আপনি ${widget.user.name}-কে আনব্লক করলে তাকে আবার দেখতে পাবেন।'
                    : 'If you unblock ${widget.user.name}, they will appear in your feed again.')
                : (bn
                    ? '${widget.user.name}-কে ব্লক করলে আপনারা একে অপরকে আর দেখতে পাবেন না এবং message পাঠাতে পারবেন না।'
                    : 'If you block ${widget.user.name}, you won\'t see each other or be able to message.'),
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(bn ? 'বাতিল' : 'Cancel',
                    style: const TextStyle(color: secondaryText))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                _isBlocked
                    ? (bn ? 'আনব্লক' : 'Unblock')
                    : (bn ? 'ব্লক' : 'Block'),
                style: TextStyle(
                    color: _isBlocked ? primaryMaroon : Colors.redAccent,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    bool success;

    if (_isBlocked) {
      success = await BlockReportService.unblockUser(
          myUid: me.uid, theirUid: widget.user.uid);
    } else {
      success = await BlockReportService.blockUser(
          myUid: me.uid, theirUid: widget.user.uid);
    }

    if (!mounted) return;
    if (success) {
      setState(() => _isBlocked = !_isBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_isBlocked ? Icons.block : Icons.check_circle,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isBlocked
                      ? (bn
                          ? '${widget.user.name}-কে ব্লক করা হয়েছে'
                          : 'Blocked ${widget.user.name}')
                      : (bn
                          ? '${widget.user.name}-কে আনব্লক করা হয়েছে'
                          : 'Unblocked ${widget.user.name}'),
                ),
              ),
            ],
          ),
          backgroundColor: _isBlocked ? Colors.orange : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (_isBlocked) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(bn ? 'কিছু সমস্যা হয়েছে।' : 'Something went wrong.'),
            backgroundColor: primaryMaroon,
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _handleReportAction(bool bn) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          ReportDialog(isBangla: bn, reportedUserName: widget.user.name),
    );

    if (result == null) return;

    final success = await BlockReportService.reportUser(
      reporterUid: me.uid,
      reportedUid: widget.user.uid,
      reason: result['reason'] as String,
      details: result['details'] as String? ?? '',
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(bn
                      ? 'আপনার রিপোর্ট পাঠানো হয়েছে। আমরা দ্রুত ব্যবস্থা নেব।'
                      : 'Your report has been sent. We will review it soon.')),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(bn ? 'রিপোর্ট পাঠানো যায়নি।' : 'Could not send report.'),
            backgroundColor: primaryMaroon,
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _openFullscreenPhoto(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenPhotoViewer(
            photoUrls: widget.user.photoUrls, initialIndex: initialIndex),
      ),
    );
  }

  // ============================================================
  // BUILD (Responsive Layout Switcher)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    final me = FirebaseAuth.instance.currentUser;
    final isMyProfile = me != null && me.uid == widget.user.uid;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(bn ? 'প্রোফাইল' : 'Profile',
            style: const TextStyle(
                color: deepMaroon, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: deepMaroon),
        actions: [
          if (!isMyProfile)
            IconButton(
              icon: _isLiking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryMaroon))
                  : Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.pink.shade600 : deepMaroon),
              tooltip: _isLiked
                  ? (bn ? 'Like সরান' : 'Unlike')
                  : (bn ? 'Like করুন' : 'Like'),
              onPressed: _isLiking ? null : _toggleLike,
            ),
          if (!isMyProfile)
            IconButton(
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? primaryMaroon : deepMaroon),
              tooltip: _isSaved
                  ? (bn ? 'সরান' : 'Remove from shortlist')
                  : (bn ? 'Save করুন' : 'Save to shortlist'),
              onPressed: _toggleShortlist,
            ),
          if (!isMyProfile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: deepMaroon),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                if (value == 'block')
                  _handleBlockAction(bn);
                else if (value == 'report') _handleReportAction(bn);
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(_isBlocked ? Icons.lock_open : Icons.block,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Text(
                          _isBlocked
                              ? (bn ? 'আনব্লক করুন' : 'Unblock')
                              : (bn ? 'ব্লক করুন' : 'Block'),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Text(bn ? 'রিপোর্ট করুন' : 'Report',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          return Column(
            children: [
              if (_isBlocked)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bn
                              ? 'আপনি এই user-কে ব্লক করেছেন'
                              : 'You have blocked this user',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: isDesktop ? _buildWebLayout(bn) : _buildMobileLayout(bn),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        children: [
          _buildProfileHeader(bn, 450),
          const SizedBox(height: 20),
          _buildInfoSection(
            title: bn ? "মৌলিক তথ্য" : "Basic Information",
            icon: Icons.person_outline,
            rows: [
              _buildRow(bn ? "লিঙ্গ" : "Gender", widget.user.gender, Icons.wc),
              _buildRow(bn ? "ধর্ম" : "Religion", widget.user.religion,
                  Icons.auto_awesome_outlined),
              _buildRow(bn ? "জেলা" : "District", widget.user.district,
                  Icons.location_on_outlined),
              _buildRow(bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                  widget.user.maritalStatus, Icons.favorite_border),
              _buildRow(
                  bn ? "উচ্চতা" : "Height", widget.user.height, Icons.height),
              _buildRow(bn ? "গায়ের রং" : "Skin Tone", widget.user.skinTone,
                  Icons.color_lens_outlined),
            ],
          ),
          _buildInfoSection(
            title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
            icon: Icons.school_outlined,
            rows: [
              _buildRow(bn ? "শিক্ষা" : "Education", widget.user.education,
                  Icons.school_outlined),
              _buildRow(bn ? "পেশা" : "Profession", widget.user.profession,
                  Icons.work_outline),
            ],
          ),
          if (widget.user.aboutMe.isNotEmpty)
            _buildInfoSection(
              title: bn ? "নিজের সম্পর্কে" : "About",
              icon: Icons.favorite_outline,
              rows: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(widget.user.aboutMe,
                      style: const TextStyle(
                          fontSize: 14, height: 1.6, color: mainText)),
                ),
              ],
            ),
          _buildInfoSection(
            title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
            icon: Icons.favorite,
            rows: [
              _buildRow(bn ? "পছন্দের বয়স" : "Preferred Age",
                  widget.user.preferredAge, Icons.cake_outlined),
              _buildRow(bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                  widget.user.preferredReligion, Icons.auto_awesome_outlined),
              _buildRow(bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                  widget.user.preferredEducation, Icons.school_outlined),
              _buildRow(bn ? "পছন্দের পেশা" : "Preferred Profession",
                  widget.user.preferredProfession, Icons.work_outline),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (টু-কলাম ডিজাইন)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔴 বাম কলাম (Profile Image)
              Expanded(
                flex: 5,
                child: _buildProfileHeader(bn, 650), // ওয়েবে ছবিটি আরেকটু বড়
              ),

              const SizedBox(width: 30),

              // 🟢 ডান কলাম (Information Sections)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildInfoSection(
                      title: bn ? "মৌলিক তথ্য" : "Basic Information",
                      icon: Icons.person_outline,
                      rows: [
                        _buildRow(bn ? "লিঙ্গ" : "Gender", widget.user.gender,
                            Icons.wc),
                        _buildRow(bn ? "ধর্ম" : "Religion",
                            widget.user.religion, Icons.auto_awesome_outlined),
                        _buildRow(bn ? "জেলা" : "District",
                            widget.user.district, Icons.location_on_outlined),
                        _buildRow(bn ? "বৈবাহিক অবস্থা" : "Marital Status",
                            widget.user.maritalStatus, Icons.favorite_border),
                        _buildRow(bn ? "উচ্চতা" : "Height", widget.user.height,
                            Icons.height),
                        _buildRow(bn ? "গায়ের রং" : "Skin Tone",
                            widget.user.skinTone, Icons.color_lens_outlined),
                      ],
                    ),
                    _buildInfoSection(
                      title: bn ? "শিক্ষা ও পেশা" : "Education & Career",
                      icon: Icons.school_outlined,
                      rows: [
                        _buildRow(bn ? "শিক্ষা" : "Education",
                            widget.user.education, Icons.school_outlined),
                        _buildRow(bn ? "পেশা" : "Profession",
                            widget.user.profession, Icons.work_outline),
                      ],
                    ),
                    if (widget.user.aboutMe.isNotEmpty)
                      _buildInfoSection(
                        title: bn ? "নিজের সম্পর্কে" : "About",
                        icon: Icons.favorite_outline,
                        rows: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(widget.user.aboutMe,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: mainText)),
                          ),
                        ],
                      ),
                    _buildInfoSection(
                      title: bn ? "জীবনসঙ্গীর পছন্দ" : "Partner Preference",
                      icon: Icons.favorite,
                      rows: [
                        _buildRow(bn ? "পছন্দের বয়স" : "Preferred Age",
                            widget.user.preferredAge, Icons.cake_outlined),
                        _buildRow(
                            bn ? "পছন্দের ধর্ম" : "Preferred Religion",
                            widget.user.preferredReligion,
                            Icons.auto_awesome_outlined),
                        _buildRow(
                            bn ? "পছন্দের শিক্ষা" : "Preferred Education",
                            widget.user.preferredEducation,
                            Icons.school_outlined),
                        _buildRow(
                            bn ? "পছন্দের পেশা" : "Preferred Profession",
                            widget.user.preferredProfession,
                            Icons.work_outline),
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
  // PROFILE HEADER (Shared between mobile and web)
  // ============================================================
  Widget _buildProfileHeader(bool bn, double height) {
    final user = widget.user;
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
            // ✅ ১. মোবাইলের জন্য পুরনো কোড (ছবি ট্যাপ = ফুলস্ক্রিন)
            // ✅ ২. ওয়েবের জন্য নতুন কোড (PageController দিয়ে স্লাইড)
            if (user.photoUrls.isNotEmpty)
              kIsWeb
                  ? PageView.builder(
                      controller: _headerPageController,
                      itemCount: user.photoUrls.length,
                      onPageChanged: (index) =>
                          setState(() => _currentPhotoIndex = index),
                      itemBuilder: (context, index) {
                        return AppNetworkImage(
                          user.photoUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: lightMaroon,
                              child: const Center(
                                  child: Icon(Icons.person,
                                      size: 120, color: primaryMaroon))),
                        );
                      },
                    )
                  : GestureDetector(
                      onTap: () => _openFullscreenPhoto(_currentPhotoIndex),
                      child: PageView.builder(
                        itemCount: user.photoUrls.length,
                        onPageChanged: (index) =>
                            setState(() => _currentPhotoIndex = index),
                        itemBuilder: (context, index) {
                          return AppNetworkImage(
                            user.photoUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: lightMaroon,
                                child: const Center(
                                    child: Icon(Icons.person,
                                        size: 120, color: primaryMaroon))),
                          );
                        },
                      ),
                    )
            else
              Container(
                  color: lightMaroon,
                  child: const Center(
                      child:
                          Icon(Icons.person, size: 120, color: primaryMaroon))),

            // ✅ ৩. শুধু ওয়েব: ছবির বাম/ডানে ট্যাপ করে ছবি বদলানোর জোন
            if (kIsWeb && user.photoUrls.length > 1)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_currentPhotoIndex > 0) {
                            _headerPageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_currentPhotoIndex < user.photoUrls.length - 1) {
                            _headerPageController.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // গ্রেডিয়েন্ট ওভারলে
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
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ),

            // ✅ ৪. ইন্ডিকেটর বার
            if (user.photoUrls.length > 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(
                    user.photoUrls.length,
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
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            )
                          : Container(
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: index == _currentPhotoIndex
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

            // ছবি সংখ্যা (2/5)
            if (user.photoUrls.length > 1)
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
                        '${_currentPhotoIndex + 1} / ${user.photoUrls.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

            // ✅ ৫. শুধু ওয়েব: ফুলস্ক্রিন বাটন
            if (kIsWeb && user.photoUrls.isNotEmpty)
              Positioned(
                bottom: 160, // নাম/বয়সের টেক্সটের উপরে
                right: 20,
                child: GestureDetector(
                  onTap: () => _openFullscreenPhoto(_currentPhotoIndex),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fullscreen,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),

            // Boosted ব্যাজ (আগের মতোই)
            if (BoostService.isBoostActive(user.boostedUntil))
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Boosted',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),

            // নাম, বয়স, জেলা, বৈবাহিক অবস্থা (আগের মতোই অক্ষত)
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
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                            color: Colors.black38,
                                            blurRadius: 10)
                                      ]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isVerified) ...[
                                const SizedBox(width: 8),
                                const VerifiedBadge(size: 24),
                              ],
                            ],
                          ),
                        ),
                        if (user.age.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1),
                            ),
                            child: Text(user.age,
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
                              user.district.isEmpty ? '—' : user.district,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (user.maritalStatus.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: Text(user.maritalStatus,
                            style: const TextStyle(
                                color: primaryMaroon,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
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
  // REUSABLE WIDGETS
  // ============================================================

  Widget _buildRow(String label, String value, IconData icon) {
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

  Widget _buildInfoSection(
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
}

// ============================================================
// FULLSCREEN PHOTO VIEWER (Untouched)
// ============================================================

class _FullscreenPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullscreenPhotoViewer({
    required this.photoUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.photoUrls.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: AppNetworkImage(
                widget.photoUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white, size: 60),
              ),
            ),
          );
        },
      ),
    );
  }
}
