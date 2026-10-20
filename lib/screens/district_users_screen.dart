import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/boost_service.dart';
import 'user_profile_view_screen.dart';
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

  // ✅ অ্যাড আনলক স্টেট
  bool _isUnlocked = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _load();
    // ✅ পেজে ঢোকার সাথে সাথেই অ্যাড দেখানোর ফাংশন কল হবে
    _showAdOnEnter();
  }

  // ✅ পেজে ঢোকার সাথে সাথে অ্যাড দেখানোর লজিক
  Future<void> _showAdOnEnter() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    // অ্যাড দেখানোর আগে লোড হতে একটু সময় দেওয়া হলো
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final success = await RewardedAdManager.showAd(onUserEarnedReward: () {});
      if (success) {
        setState(() => _isUnlocked = true);
      }
    } catch (e) {
      debugPrint('❌ Ad show error: $e');
    } finally {
      if (mounted) setState(() => _isUnlocking = false);
    }
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
      body: _buildBody(bn),
    );
  }

  Widget _buildBody(bool bn) {
    if (_isLoading || _isUnlocking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: primaryMaroon),
            const SizedBox(height: 16),
            Text(bn ? 'অ্যাড লোড হচ্ছে...' : 'Loading ad...',
                style: const TextStyle(color: secondaryText)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    // ✅ ইউজার অ্যাড না দেখলে লক স্ক্রিন দেখাবে
    if (!_isUnlocked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: primaryGold),
              const SizedBox(height: 20),
              Text(
                bn ? 'প্রোফাইলগুলো লক করা আছে' : 'Profiles are locked',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon),
              ),
              const SizedBox(height: 10),
              Text(
                bn
                    ? 'এই জেলার প্রোফাইলগুলো দেখতে একটি ছোট বিজ্ঞাপন দেখুন।'
                    : 'Watch a short ad to view profiles in this district.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: secondaryText),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAdOnEnter,
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(
                      bn ? '🎬 অ্যাড দেখে আনলক করুন' : '🎬 Watch Ad to Unlock',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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

    if (_users.isEmpty) {
      return const Center(child: Text('কেউ নেই / No one found'));
    }

    // ✅ আনলকড থাকলে প্রোফাইল লিস্ট
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (context, i) => _buildUserCard(_users[i], bn),
    );
  }

  Widget _buildUserCard(UserProfile user, bool bn) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => UserProfileViewScreen(
                      isBangla: widget.isBangla, user: user)));
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
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
                      ? CachedNetworkImage(
                          imageUrl: user.photoUrl, fit: BoxFit.cover)
                      : const Icon(Icons.person,
                          size: 40, color: primaryMaroon),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty ? '—' : user.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${user.age} • ${user.district}',
                        style: const TextStyle(
                            fontSize: 12, color: secondaryText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}
