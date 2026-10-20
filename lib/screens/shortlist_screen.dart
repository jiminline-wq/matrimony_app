import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../utils/shortlist_service.dart';
import 'user_profile_view_screen.dart';
import '../ads/banner_ad_widget.dart';
import '../ads/ad_config.dart';
import '../ads/rewarded_ad_manager.dart';

class ShortlistScreen extends StatefulWidget {
  final bool isBangla;

  const ShortlistScreen({super.key, required this.isBangla});

  @override
  State<ShortlistScreen> createState() => _ShortlistScreenState();
}

class _ShortlistScreenState extends State<ShortlistScreen> {
  List<Map<String, dynamic>> saved = [];
  bool isLoading = true;

  // ✅ অ্যাড আনলক স্টেট
  bool _isUnlocked = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    loadSaved();
    // ✅ পেজে ঢোকার সাথে সাথেই অ্যাড দেখানোর ফাংশন কল হবে
    _showAdOnEnter();
  }

  // ✅ পেজে ঢোকার সাথে সাথে অ্যাড দেখানোর লজিক
  Future<void> _showAdOnEnter() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

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

  Future<void> loadSaved() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shortlists')
          .doc(me.uid)
          .collection('saved')
          .orderBy('savedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> loaded = [];

      for (final doc in snapshot.docs) {
        final uid = doc.data()['savedUid'] as String? ?? '';
        if (uid.isEmpty) continue;

        final profileDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (profileDoc.exists) {
          loaded.add({
            'profile':
                UserProfile.fromMap(profileDoc.data()!, docId: profileDoc.id),
            'savedAt': doc.data()['savedAt'],
          });
        }
      }

      setState(() {
        saved = loaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeFromShortlist(UserProfile profile) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final bn = widget.isBangla;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(bn ? 'সরিয়ে ফেলবেন?' : 'Remove?'),
        content: Text(bn
            ? '${profile.name}-কে সরিয়ে ফেলবেন?'
            : 'Remove ${profile.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(bn ? 'বাতিল' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(bn ? 'সরান' : 'Remove',
                  style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;
    final success =
        await ShortlistService.removeUser(myUid: me.uid, theirUid: profile.uid);
    if (success) loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(title: Text(bn ? 'সংরক্ষিত প্রোফাইল' : 'Saved Profiles')),
      body: Column(
        children: [
          Expanded(child: _buildBody(bn)),
          const BannerAdWidget(placementId: AdConfig.placementSaved),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn) {
    if (isLoading || _isUnlocking) {
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
                    ? 'আপনার সেভ করা প্রোফাইলগুলো দেখতে একটি ছোট বিজ্ঞাপন দেখুন।'
                    : 'Watch a short ad to view your saved profiles.',
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

    if (saved.isEmpty) {
      return Center(
          child: Text(
              bn ? 'এখনো কোনো profile save করেননি' : 'No saved profiles yet'));
    }

    // ✅ আনলকড থাকলে প্রোফাইল লিস্ট
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        final item = saved[index];
        final profile = item['profile'] as UserProfile;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => UserProfileViewScreen(
                            isBangla: bn, user: profile))),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: lightMaroon),
                  child: ClipOval(
                    child: profile.photoUrl.isNotEmpty
                        ? Image.network(profile.photoUrl, fit: BoxFit.cover)
                        : const Icon(Icons.person, color: primaryMaroon),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${profile.age} • ${profile.district}',
                        style: const TextStyle(
                            fontSize: 12, color: secondaryText)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeFromShortlist(profile),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
        );
      },
    );
  }
}
