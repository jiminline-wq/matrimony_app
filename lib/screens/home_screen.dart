import 'dart:async';
import '../services/engagement_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/colors.dart';
import '../services/badge_service.dart';
import '../services/call_service.dart';
import '../services/call_history_service.dart';
import 'home_tab.dart'; // ✅ NEW
import 'my_profile_tab.dart';
import 'discover_tab.dart';
import 'matches_tab.dart';
import 'nearby_tab.dart';
import 'call_screen.dart';
import 'call_history_screen.dart';

// ============================================================
// HOME SCREEN — 6 Tabs + Badges + Incoming Call Listener
// ============================================================

class HomeScreen extends StatefulWidget {
  final bool isBangla;
  final int initialIndex;

  const HomeScreen({super.key, required this.isBangla, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ✅ সব variable class-এর শুরুতেই declare
  late int _currentIndex;

  // Incoming call listener
  StreamSubscription<QuerySnapshot>? _incomingCallSub;
  String? _currentIncomingCallId;
  bool _isCallScreenOpen = false;

  // ============================================================
  // INIT
  // ============================================================
  @override
  void initState() {
    super.initState();
    // ✅ 6 tabs — index 0 থেকে 5
    _checkDailyStreak();
    _currentIndex = widget.initialIndex.clamp(0, 5);
    _listenForIncomingCalls();
  }

  Future<void> _checkDailyStreak() async {
    final result = await EngagementService.checkAndUpdateStreak();

    if (result != null && mounted) {
      // ✅ যদি রিওয়ার্ড পাওয়া যায়, তবে একটি Dialog দেখান
      if (result['rewardGranted'] == true) {
        _showRewardDialog(result['message']);
      }
      // ✅ শুধু স্ট্রিক আপডেট হলে একটি Snackbar দেখান (অপশনাল)
      else if (result['streak'] > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔥 আপনি ${result['streak']} দিন টানা লগইন করেছেন!'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

// ✅ রিওয়ার্ড ডায়ালগ UI
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

  // ============================================================
  // INCOMING CALL LISTENER
  // ============================================================
  void _listenForIncomingCalls() {
    _incomingCallSub = CallService.incomingCallStream().listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) return;
      if (_isCallScreenOpen) return; // already showing a call

      final callDoc = snap.docs.first;
      final data = callDoc.data() as Map<String, dynamic>;
      final callId = callDoc.id;

      // ✅ একই call-এ আবার navigate না করার জন্য
      if (_currentIncomingCallId == callId) return;
      _currentIncomingCallId = callId;
      _isCallScreenOpen = true;

      debugPrint(
        '📞 Incoming call detected: $callId from ${data['callerName']}',
      );

      // ✅ navigate after frame (context ready)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              isBangla: widget.isBangla,
              channelName: data['channelName'] ?? '',
              otherUserName: data['callerName'] ?? 'Unknown',
              otherUserPhoto: data['callerPhoto'] ?? '',
              isVideoCall: data['isVideoCall'] == true,
              isCaller: false,
              callId: callId,
              isIncoming: true,
            ),
          ),
        ).then((_) {
          // CallScreen pop হলে flags reset
          _isCallScreenOpen = false;
          _currentIncomingCallId = null;
        });
      });
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _incomingCallSub?.cancel();
    super.dispose();
  }

  // ============================================================
  // TAB TAP
  // ============================================================
  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    // ✅ 6 tabs — Home সবার আগে
    final List<Widget> tabs = [
      HomeTab(isBangla: bn), // ✅ 0 — Home
      DiscoverTab(isBangla: bn), // 1 — Discover
      NearbyTab(isBangla: bn), // 2 — Nearby
      MatchesTab(isBangla: bn), // 3 — Matches
      CallHistoryScreen(isBangla: bn), // 4 — Calls
      MyProfileTab(isBangla: bn), // 5 — Profile (শেষে)
    ];

    return Scaffold(
      backgroundColor: warmWhite,
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: primaryMaroon.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: StreamBuilder<int>(
            stream: BadgeService.streamNewMatchCount(),
            builder: (context, matchSnap) {
              final matchBadge = matchSnap.data ?? 0;

              return StreamBuilder<int>(
                stream: CallHistoryService.streamMissedCount(),
                builder: (context, missedSnap) {
                  final missedCount = missedSnap.data ?? 0;

                  return BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onTabTap,
                    backgroundColor: Colors.white,
                    selectedItemColor: primaryMaroon,
                    unselectedItemColor: secondaryText,
                    selectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                    unselectedLabelStyle: const TextStyle(fontSize: 9),
                    type: BottomNavigationBarType.fixed,
                    elevation: 0,
                    selectedFontSize: 10,
                    unselectedFontSize: 9,
                    items: [
                      // ✅ 1. Home
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.home_outlined, size: 22),
                        activeIcon: const Icon(Icons.home, size: 22),
                        label: bn ? 'হোম' : 'Home',
                      ),

                      // 2. Discover
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.explore_outlined, size: 22),
                        activeIcon: const Icon(Icons.explore, size: 22),
                        label: bn ? 'খুঁজুন' : 'Discover',
                      ),

                      // 3. Nearby
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.location_on_outlined, size: 22),
                        activeIcon: const Icon(Icons.location_on, size: 22),
                        label: bn ? 'নিকটবর্তী' : 'Nearby',
                      ),

                      // 4. Matches (with badge)
                      BottomNavigationBarItem(
                        icon: BadgedIcon(
                          icon: Icons.favorite_outline,
                          count: matchBadge,
                          iconColor: secondaryText,
                          badgeColor: primaryMaroon,
                        ),
                        activeIcon: BadgedIcon(
                          icon: Icons.favorite,
                          count: matchBadge,
                          iconColor: primaryMaroon,
                          badgeColor: primaryMaroon,
                        ),
                        label: bn ? 'ম্যাচ' : 'Matches',
                      ),

                      // 5. Calls (with missed badge)
                      BottomNavigationBarItem(
                        icon: BadgedIcon(
                          icon: Icons.call_outlined,
                          count: missedCount,
                          iconColor: secondaryText,
                          badgeColor: Colors.red,
                        ),
                        activeIcon: BadgedIcon(
                          icon: Icons.call,
                          count: missedCount,
                          iconColor: primaryMaroon,
                          badgeColor: Colors.red,
                        ),
                        label: bn ? 'কল' : 'Calls',
                      ),

                      // 6. Profile
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.person_outline, size: 22),
                        activeIcon: const Icon(Icons.person, size: 22),
                        label: bn ? 'প্রোফাইল' : 'Profile',
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
