import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

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

    // ✅ ওয়েবের জন্য সরাসরি আনলক
    if (kIsWeb) {
      _isUnlocked = true;
    } else {
      // ✅ মোবাইলে পেজে ঢোকার সাথে সাথেই অ্যাড দেখানোর ফাংশন কল হবে
      _showAdOnEnter();
    }
  }

  // ✅ পেজে ঢোকার সাথে সাথে অ্যাড দেখানোর লজিক
  Future<void> _showAdOnEnter() async {
    if (_isUnlocking || kIsWeb) return;
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
      appBar: AppBar(
        backgroundColor: warmWhite,
        elevation: 0,
        title: Text(bn ? 'সংরক্ষিত প্রোফাইল' : 'Saved Profiles',
            style: const TextStyle(
                color: deepMaroon, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: deepMaroon),
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
          if (_isUnlocked && !kIsWeb)
            const BannerAdWidget(placementId: AdConfig.placementSaved),
        ],
      ),
    );
  }

  Widget _buildBody(bool bn, bool isDesktop) {
    if (isLoading || _isUnlocking) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: primaryMaroon),
            if (_isUnlocking) ...[
              const SizedBox(height: 16),
              Text(bn ? 'অ্যাড লোড হচ্ছে...' : 'Loading ad...',
                  style: const TextStyle(color: secondaryText)),
            ]
          ],
        ),
      );
    }

    // ✅ ইউজার অ্যাড না দেখলে লক স্ক্রিন দেখাবে (শুধু মোবাইলে)
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
            bn ? 'এখনো কোনো profile save করেননি' : 'No saved profiles yet',
            style: const TextStyle(fontSize: 16, color: secondaryText)),
      );
    }

    // ✅ আনলকড থাকলে মোবাইল বা ওয়েব লেআউট দেখাবে
    return isDesktop ? _buildWebLayout(bn) : _buildMobileLayout(bn);
  }

  // ============================================================
  // 📱 ১. মোবাইল লেআউট (হুবহু অক্ষত)
  // ============================================================
  Widget _buildMobileLayout(bool bn) {
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
                        ? Image.network(profile.photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, color: primaryMaroon))
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
                        color: primaryMaroon.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.bookmark,
                        color: primaryMaroon, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn ? 'সংরক্ষিত প্রোফাইল' : 'Saved Profiles',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: deepMaroon),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bn
                            ? 'মোট ${saved.length} জনকে সেভ করেছেন'
                            : '${saved.length} profiles saved',
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
                  mainAxisExtent: 320, // কার্ডের নির্দিষ্ট উচ্চতা
                ),
                itemCount: saved.length,
                itemBuilder: (context, index) {
                  final item = saved[index];
                  final profile = item['profile'] as UserProfile;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ইমেজ
                        Expanded(
                          flex: 5,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: profile.photoUrl.isNotEmpty
                                ? Image.network(profile.photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder())
                                : _imgPlaceholder(),
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
                                      profile.name.isEmpty
                                          ? 'নাম নেই'
                                          : profile.name,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: mainText),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${profile.age} • ${profile.district}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: secondaryText)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    UserProfileViewScreen(
                                                        isBangla: bn,
                                                        user: profile))),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: primaryMaroon,
                                          side: BorderSide(
                                              color: primaryMaroon.withValues(
                                                  alpha: 0.3)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                        child: Text(bn ? 'দেখুন' : 'View',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () =>
                                          _removeFromShortlist(profile),
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.redAccent),
                                      style: IconButton.styleFrom(
                                        backgroundColor:
                                            Colors.red.withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
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
                },
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
}
