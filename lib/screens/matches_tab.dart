import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/verified_badge.dart';
import '../utils/ai_match_service.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ✅ Deferred Loading Imports
import 'chat_screen.dart' deferred as chat_screen_lib;
import 'user_profile_view_screen.dart' deferred as user_profile_view_lib;

// ============================================================
// MATCHES TAB — AI Match Score Added
// ============================================================

class MatchesTab extends StatefulWidget {
  final bool isBangla;

  const MatchesTab({super.key, required this.isBangla});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  List<Map<String, dynamic>> matches = [];
  bool isLoading = true;
  UserProfile? _myProfile;

  @override
  void initState() {
    super.initState();
    loadMatches();
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

  // ============================================================
  // LOAD MATCHES + CALCULATE AI SCORE
  // ============================================================
  Future<void> loadMatches() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // ✅ ১. প্রথমে নিজের প্রোফাইল লোড করুন
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (myDoc.exists) {
        _myProfile = UserProfile.fromMap(myDoc.data()!, docId: myDoc.id);
      }

      // ✅ ২. ম্যাচ কালেকশন থেকে ডেটা আনুন
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('users', arrayContains: currentUser.uid)
          .get();

      final List<Map<String, dynamic>> loadedMatches = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final u1 = data['user1'] as Map<String, dynamic>? ?? {};
        final u2 = data['user2'] as Map<String, dynamic>? ?? {};

        final otherUserMap = u1['uid'] == currentUser.uid ? u2 : u1;
        final otherUid = otherUserMap['uid'] as String? ?? '';

        if (otherUid.isEmpty) continue;

        // Deactivated চেক এবং পুরো প্রোফাইল লোড
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            if (userData['isDeactivated'] == true) {
              continue; // Deactivated → skip
            }

            final otherUserProfile =
                UserProfile.fromMap(userData, docId: userDoc.id);

            // ✅ ৩. অ্যাডভান্সড AI Match Score ক্যালকুলেট করুন
            double matchScore = 50.0;
            if (_myProfile != null) {
              matchScore =
                  AiMatchService.calculateScore(_myProfile!, otherUserProfile);
            }

            loadedMatches.add({
              'matchId': doc.id,
              'user': otherUserMap,
              'profile': otherUserProfile,
              'score': matchScore,
            });
          }
        } catch (_) {}
      }

      // ✅ ৪. স্কোর অনুযায়ী সর্ট করুন
      loadedMatches.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      setState(() {
        matches = loadedMatches;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // OPEN CHAT
  // ============================================================
  void _openChat(Map<String, dynamic> otherUser, bool bn) {
    _navigateDeferred(
      chat_screen_lib.loadLibrary(),
      () => chat_screen_lib.ChatScreen(
        isBangla: bn,
        otherUserId: otherUser['uid'] ?? '',
        otherUserName: otherUser['name'] ?? '',
        otherUserPhoto: otherUser['photoUrl'] ?? '',
      ),
    );
  }

  // ============================================================
  // OPEN PROFILE
  // ============================================================
  Future<void> _openProfile(Map<String, dynamic> otherUser, bool bn) async {
    final uid = otherUser['uid'] as String? ?? '';
    if (uid.isEmpty) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bn ? 'প্রোফাইল পাওয়া যায়নি' : 'Profile not found'),
            backgroundColor: primaryMaroon,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;

      final profile = UserProfile.fromMap(doc.data()!, docId: doc.id);
      
      _navigateDeferred(
        user_profile_view_lib.loadLibrary(),
        () => user_profile_view_lib.UserProfileViewScreen(
          isBangla: bn,
          user: profile,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bn ? 'লোড করা যায়নি' : 'Could not load'),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          bn ? 'আমার ম্যাচ' : 'My Matches',
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
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 800;
                return _buildBody(bn, isDesktop);
              },
            ),
          ),

          // ✅ AdMob শুধু মোবাইলে
          if (!kIsWeb)
            const SafeArea(
              top: false,
              child: BannerAdWidget(placementId: AdConfig.placementMatches),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn, bool isDesktop) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: primaryMaroon));
    }

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightMaroon,
                ),
                child: const Icon(
                  Icons.favorite_border,
                  size: 60,
                  color: primaryMaroon,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                bn ? 'এখনো কোনো ম্যাচ নেই' : 'No matches yet',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                bn
                    ? 'Discover tab-এ গিয়ে like করুন। mutually like হলে এখানে দেখা যাবে।'
                    : 'Go to Discover tab and like. When mutual, they will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: secondaryText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => isLoading = true);
                  loadMatches();
                },
                icon: const Icon(Icons.refresh),
                label: Text(bn ? 'রিফ্রেশ' : 'Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ আনলকড থাকলে মোবাইল বা ওয়েব লেআউট দেখাবে
    return isDesktop ? _buildWebLayout(bn) : _buildMobileLayout(bn);
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
    return RefreshIndicator(
      onRefresh: loadMatches,
      color: primaryMaroon,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final match = matches[index];
          final otherUser = match['user'] as Map<String, dynamic>;
          final score = match['score'] as double? ?? 0.0;

          return _buildMobileMatchCard(otherUser, bn, score);
        },
      ),
    );
  }

  Widget _buildMobileMatchCard(
      Map<String, dynamic> otherUser, bool bn, double score) {
    final isVerified = otherUser['isVerified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row — Photo + Info
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightMaroon,
                  border: Border.all(color: primaryGold, width: 2),
                ),
                child: ClipOval(
                  child: (otherUser['photoUrl'] as String? ?? '').isNotEmpty
                      ? Image.network(
                          otherUser['photoUrl'],
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person,
                              size: 35, color: primaryMaroon),
                        )
                      : const Icon(Icons.person,
                          size: 35, color: primaryMaroon),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite,
                            size: 16, color: primaryMaroon),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  otherUser['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: mainText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 5),
                                const VerifiedBadge(size: 16),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${otherUser['age'] ?? ''} • ${otherUser['district'] ?? ''}',
                      style:
                          const TextStyle(fontSize: 13, color: secondaryText),
                    ),
                    const SizedBox(height: 4),

                    // ✅ AI MATCH SCORE BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: score >= 70
                            ? Colors.green.withValues(alpha: 0.1)
                            : (score >= 40
                                ? Colors.orange.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: score >= 70
                              ? Colors.green
                              : (score >= 40 ? Colors.orange : Colors.red),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: score >= 70
                                ? Colors.green
                                : (score >= 40 ? Colors.orange : Colors.red),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bn
                                ? 'AI ম্যাচ: ${score.toStringAsFixed(0)}%'
                                : 'AI Match: ${score.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: score >= 70
                                  ? Colors.green
                                  : (score >= 40 ? Colors.orange : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Row — Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openProfile(otherUser, bn),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: Text(bn ? 'প্রোফাইল' : 'Profile',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryMaroon,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: primaryMaroon, width: 1.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _openChat(otherUser, bn),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(bn ? 'মেসেজ পাঠান' : 'Send Message',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 💻 ২. ওয়েব লেআউট (নতুন প্রিমিয়াম গ্রিড ভিউ)
  // ============================================================
  Widget _buildWebLayout(bool bn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // হেডার
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.favorite,
                        color: Colors.pink, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn ? 'আমার ম্যাচ' : 'My Matches',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bn
                            ? 'মোট ${matches.length}টি ম্যাচ পাওয়া গেছে'
                            : '${matches.length} matches found',
                        style:
                            const TextStyle(fontSize: 14, color: secondaryText),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // গ্রিড ভিউ
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  mainAxisExtent: 380, // কার্ডের নির্দিষ্ট উচ্চতা
                ),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final otherUser = match['user'] as Map<String, dynamic>;
                  final score = match['score'] as double? ?? 0.0;

                  return _buildWebMatchCard(otherUser, bn, score);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebMatchCard(
      Map<String, dynamic> otherUser, bool bn, double score) {
    final isVerified = otherUser['isVerified'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ইমেজ
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (otherUser['photoUrl'] as String? ?? '').isNotEmpty
                      ? Image.network(
                          otherUser['photoUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                  // ওভারলে গ্রেডিয়েন্ট
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  otherUser['name'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 5),
                                const VerifiedBadge(size: 18),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ইনফো
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${otherUser['age'] ?? ''} • ${otherUser['district'] ?? ''}',
                        style:
                            const TextStyle(fontSize: 13, color: secondaryText),
                      ),
                      const SizedBox(height: 8),
                      // AI Match Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: score >= 70
                              ? Colors.green.withValues(alpha: 0.1)
                              : (score >= 40
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1)),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: score >= 70
                              ? Colors.green
                              : (score >= 40 ? Colors.orange : Colors.red),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: score >= 70
                                ? Colors.green
                                : (score >= 40 ? Colors.orange : Colors.red),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bn
                                ? 'AI ম্যাচ: ${score.toStringAsFixed(0)}%'
                                : 'AI Match: ${score.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: score >= 70
                                  ? Colors.green
                                  : (score >= 40
                                      ? Colors.orange
                                      : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openProfile(otherUser, bn),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryMaroon,
                            side: BorderSide(
                                color: primaryMaroon.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(bn ? 'প্রোফাইল' : 'Profile',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _openChat(otherUser, bn),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(bn ? 'মেসেজ' : 'Message',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: lightMaroon,
      child: const Center(
          child: Icon(Icons.person, size: 80, color: primaryMaroon)),
    );
  }
}