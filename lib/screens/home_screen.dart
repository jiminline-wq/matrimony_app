import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../services/badge_service.dart';
import '../services/call_service.dart';
import '../services/call_history_service.dart';
import '../services/engagement_service.dart';
import 'home_tab.dart';
import 'my_profile_tab.dart';
import 'discover_tab.dart';
import 'matches_tab.dart';
import 'nearby_tab.dart';
import 'call_screen.dart';
import 'call_history_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isBangla;
  final int initialIndex;

  const HomeScreen({super.key, required this.isBangla, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  StreamSubscription<QuerySnapshot>? _incomingCallSub;
  String? _currentIncomingCallId;
  bool _isCallScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _checkDailyStreak();
    _currentIndex = widget.initialIndex.clamp(0, 5);
    _listenForIncomingCalls();
  }

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
          ),
        );
      }
    }
  }

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

  void _listenForIncomingCalls() {
    _incomingCallSub = CallService.incomingCallStream().listen((snap) {
      if (!mounted || snap.docs.isEmpty || _isCallScreenOpen) return;

      final callDoc = snap.docs.first;
      final data = callDoc.data() as Map<String, dynamic>;
      final callId = callDoc.id;

      if (_currentIncomingCallId == callId) return;
      _currentIncomingCallId = callId;
      _isCallScreenOpen = true;

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
          _isCallScreenOpen = false;
          _currentIncomingCallId = null;
        });
      });
    });
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    final List<Widget> tabs = [
      HomeTab(isBangla: bn),
      DiscoverTab(isBangla: bn),
      NearbyTab(isBangla: bn),
      MatchesTab(isBangla: bn),
      CallHistoryScreen(isBangla: bn),
      MyProfileTab(isBangla: bn),
    ];

    // ✅ ওয়েবের জন্য সাইডবার মেনু এবং মোবাইলের জন্য বটম নেভিগেশন
    return Scaffold(
      backgroundColor: warmWhite,
      body: kIsWeb
          ? Row(
              children: [
                _buildWebSidebar(bn),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: tabs),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: kIsWeb ? null : _buildMobileBottomNav(bn),
    );
  }

  // ============================================================
  // 💻 ওয়েবের জন্য সাইডবার (Navigation Rail)
  // ============================================================
  Widget _buildWebSidebar(bool bn) {
    return StreamBuilder<int>(
      stream: BadgeService.streamNewMatchCount(),
      builder: (context, matchSnap) {
        final matchBadge = matchSnap.data ?? 0;
        return StreamBuilder<int>(
          stream: CallHistoryService.streamMissedCount(),
          builder: (context, missedSnap) {
            final missedCount = missedSnap.data ?? 0;

            return NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabTap,
              extended: true, // ✅ ওয়েবে টেক্সট সহ দেখাবে
              minExtendedWidth: 200,
              selectedIconTheme: const IconThemeData(color: primaryMaroon),
              selectedLabelTextStyle: const TextStyle(
                  color: primaryMaroon,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedLabelTextStyle:
                  const TextStyle(color: secondaryText, fontSize: 15),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Column(
                  children: [
                    Image.asset('assets/logo.png', width: 60, height: 60),
                    const SizedBox(height: 10),
                    Text(
                      bn ? 'জীবন সাথী' : 'Jibon Sathi',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: deepMaroon),
                    ),
                  ],
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text(bn ? 'হোম' : 'Home'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore),
                  label: Text(bn ? 'খুঁজুন' : 'Discover'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.location_on_outlined),
                  selectedIcon: const Icon(Icons.location_on),
                  label: Text(bn ? 'নিকটবর্তী' : 'Nearby'),
                ),
                NavigationRailDestination(
                  icon: BadgedIcon(
                      icon: Icons.favorite_outline,
                      count: matchBadge,
                      iconColor: secondaryText,
                      badgeColor: primaryMaroon),
                  selectedIcon: BadgedIcon(
                      icon: Icons.favorite,
                      count: matchBadge,
                      iconColor: primaryMaroon,
                      badgeColor: primaryMaroon),
                  label: Text(bn ? 'ম্যাচ' : 'Matches'),
                ),
                NavigationRailDestination(
                  icon: BadgedIcon(
                      icon: Icons.call_outlined,
                      count: missedCount,
                      iconColor: secondaryText,
                      badgeColor: Colors.red),
                  selectedIcon: BadgedIcon(
                      icon: Icons.call,
                      count: missedCount,
                      iconColor: primaryMaroon,
                      badgeColor: Colors.red),
                  label: Text(bn ? 'কল' : 'Calls'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: Text(bn ? 'প্রোফাইল' : 'Profile'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 📱 মোবাইলের জন্য বটম নেভিগেশন
  // ============================================================
  Widget _buildMobileBottomNav(bool bn) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: primaryMaroon.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3)),
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
                      fontWeight: FontWeight.bold, fontSize: 10),
                  unselectedLabelStyle: const TextStyle(fontSize: 9),
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  items: [
                    BottomNavigationBarItem(
                        icon: const Icon(Icons.home_outlined, size: 22),
                        activeIcon: const Icon(Icons.home, size: 22),
                        label: bn ? 'হোম' : 'Home'),
                    BottomNavigationBarItem(
                        icon: const Icon(Icons.explore_outlined, size: 22),
                        activeIcon: const Icon(Icons.explore, size: 22),
                        label: bn ? 'খুঁজুন' : 'Discover'),
                    BottomNavigationBarItem(
                        icon: const Icon(Icons.location_on_outlined, size: 22),
                        activeIcon: const Icon(Icons.location_on, size: 22),
                        label: bn ? 'নিকটবর্তী' : 'Nearby'),
                    BottomNavigationBarItem(
                      icon: BadgedIcon(
                          icon: Icons.favorite_outline,
                          count: matchBadge,
                          iconColor: secondaryText,
                          badgeColor: primaryMaroon),
                      activeIcon: BadgedIcon(
                          icon: Icons.favorite,
                          count: matchBadge,
                          iconColor: primaryMaroon,
                          badgeColor: primaryMaroon),
                      label: bn ? 'ম্যাচ' : 'Matches',
                    ),
                    BottomNavigationBarItem(
                      icon: BadgedIcon(
                          icon: Icons.call_outlined,
                          count: missedCount,
                          iconColor: secondaryText,
                          badgeColor: Colors.red),
                      activeIcon: BadgedIcon(
                          icon: Icons.call,
                          count: missedCount,
                          iconColor: primaryMaroon,
                          badgeColor: Colors.red),
                      label: bn ? 'কল' : 'Calls',
                    ),
                    BottomNavigationBarItem(
                        icon: const Icon(Icons.person_outline, size: 22),
                        activeIcon: const Icon(Icons.person, size: 22),
                        label: bn ? 'প্রোফাইল' : 'Profile'),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// BadgedIcon উইজেটটি এখানে ডিক্লেয়ার করা হলো যাতে সাইডবার ও বটম বার দুটোতেই ব্যবহার করা যায়
class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color iconColor;
  final Color badgeColor;

  const BadgedIcon(
      {super.key,
      required this.icon,
      required this.count,
      required this.iconColor,
      required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Icon(icon, size: 22, color: iconColor),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration:
                  BoxDecoration(color: badgeColor, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
