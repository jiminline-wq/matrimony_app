import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import 'chat_screen.dart';
import 'user_profile_view_screen.dart';
import '../widgets/notification_bell.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/verified_badge.dart';
import '../utils/ai_match_service.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          isBangla: bn,
          otherUserId: otherUser['uid'] ?? '',
          otherUserName: otherUser['name'] ?? '',
          otherUserPhoto: otherUser['photoUrl'] ?? '',
        ),
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileViewScreen(isBangla: bn, user: profile),
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
          Expanded(child: _buildBody(bn)),

          // ✅ Fixed Banner Ad at the bottom
          const BannerAdWidget(
            placementId: AdConfig.placementMatches,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      );
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
                  setState(() {
                    isLoading = true;
                  });
                  loadMatches();
                },
                icon: const Icon(Icons.refresh),
                label: Text(bn ? 'রিফ্রেশ' : 'Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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

          return _buildMatchCard(otherUser, bn, score);
        },
      ),
    );
  }

  // ============================================================
  // MATCH CARD
  // ============================================================
  Widget _buildMatchCard(
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
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 35,
                            color: primaryMaroon,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 35,
                          color: primaryMaroon,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: primaryMaroon,
                        ),
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
                                    color: mainText,
                                  ),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
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
              // View Profile button (Outlined)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openProfile(otherUser, bn),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: Text(
                    bn ? 'প্রোফাইল' : 'Profile',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryMaroon,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: primaryMaroon, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Message button (Filled)
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _openChat(otherUser, bn),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(
                    bn ? 'মেসেজ পাঠান' : 'Send Message',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
}
