import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../models/call_history_entry.dart';
import '../services/call_history_service.dart';
import '../services/call_service.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ============================================================
// CALL HISTORY SCREEN — 4 tabs
// ============================================================

class CallHistoryScreen extends StatefulWidget {
  final bool isBangla;

  const CallHistoryScreen({super.key, required this.isBangla});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;

    return Scaffold(
      backgroundColor: warmWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryMaroon),
        title: Text(
          bn ? 'কল হিস্ট্রি' : 'Call History',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _confirmClearAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: primaryMaroon,
          unselectedLabelColor: secondaryText,
          indicatorColor: primaryMaroon,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: bn ? 'সব' : 'All'),
            Tab(text: bn ? 'মিসড' : 'Missed'),
            Tab(text: bn ? 'আউটগোয়িং' : 'Outgoing'),
            Tab(text: bn ? 'ইনকামিং' : 'Incoming'),
          ],
        ),
      ),
      // ✅ Column + Expanded ব্যবহার করে নিচে ব্যানার অ্যাড বসানো হলো
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CallHistoryEntry>>(
              stream: CallHistoryService.streamHistory(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryMaroon),
                  );
                }

                final all = snap.data ?? [];

                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(all, bn, 'all'),
                    _buildList(
                      all.where((e) => e.isMissedFor(_myUid ?? '')).toList(),
                      bn,
                      'missed',
                    ),
                    _buildList(
                      all.where((e) => e.isOutgoing(_myUid ?? '')).toList(),
                      bn,
                      'outgoing',
                    ),
                    _buildList(
                      all.where((e) => !e.isOutgoing(_myUid ?? '')).toList(),
                      bn,
                      'incoming',
                    ),
                  ],
                );
              },
            ),
          ),
          // ✅ Fixed Banner Ad
          const BannerAdWidget(
            placementId: AdConfig.placementCallHistory,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIST BUILDER
  // ============================================================
  Widget _buildList(List<CallHistoryEntry> items, bool bn, String tab) {
    if (items.isEmpty) {
      return _buildEmptyState(bn, tab);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildTile(items[i], bn),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState(bool bn, String tab) {
    IconData icon;
    String title;
    String subtitle;

    switch (tab) {
      case 'missed':
        icon = Icons.phone_missed;
        title = bn ? 'কোনো মিসড কল নেই' : 'No missed calls';
        subtitle = bn ? 'সব কল ধরেছেন!' : 'You caught them all!';
        break;
      case 'outgoing':
        icon = Icons.call_made;
        title = bn ? 'কোনো আউটগোয়িং কল নেই' : 'No outgoing calls';
        subtitle = bn ? 'কাউকে কল দিন' : 'Call someone';
        break;
      case 'incoming':
        icon = Icons.call_received;
        title = bn ? 'কোনো ইনকামিং কল নেই' : 'No incoming calls';
        subtitle = bn ? 'অপেক্ষা করুন' : 'Wait for calls';
        break;
      default:
        icon = Icons.call;
        title = bn ? 'কোনো কল নেই' : 'No calls yet';
        subtitle = bn ? 'কল শুরু করুন' : 'Start calling';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: primaryMaroon.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: mainText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: secondaryText),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TILE
  // ============================================================
  Widget _buildTile(CallHistoryEntry entry, bool bn) {
    final uid = _myUid ?? '';
    final isOutgoing = entry.isOutgoing(uid);
    final isMissed = entry.isMissedFor(uid);
    final isRejected = entry.status == 'rejected';
    final otherName = entry.otherUserName(uid);
    final otherPhoto = entry.otherUserPhoto(uid);

    IconData dirIcon;
    Color dirColor;
    if (isMissed) {
      dirIcon = Icons.call_missed;
      dirColor = Colors.red;
    } else if (isRejected && isOutgoing) {
      dirIcon = Icons.call_missed_outgoing;
      dirColor = Colors.red.shade400;
    } else if (isOutgoing) {
      dirIcon = Icons.call_made;
      dirColor = Colors.green;
    } else {
      dirIcon = Icons.call_received;
      dirColor = Colors.blue;
    }

    String subtitle;
    if (isMissed) {
      subtitle = bn ? 'মিসড কল' : 'Missed';
    } else if (isRejected) {
      subtitle = isOutgoing
          ? (bn ? 'বাতিল হয়েছে' : 'Declined')
          : (bn ? 'আপনি বাতিল করেছেন' : 'You declined');
    } else if (entry.status == 'ended' && entry.duration > 0) {
      subtitle = entry.formattedDuration;
    } else {
      subtitle = bn ? 'সম্পন্ন' : 'Completed';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openChat(entry, uid),
          onLongPress: () => _showOptions(entry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: lightMaroon,
                      ),
                      child: ClipOval(
                        child: otherPhoto.isNotEmpty
                            ? Image.network(
                                otherPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: primaryMaroon,
                                ),
                              )
                            : const Icon(Icons.person, color: primaryMaroon),
                      ),
                    ),
                    // Direction icon badge
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(dirIcon, size: 14, color: dirColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isMissed ? Colors.red : mainText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            entry.isVideoCall ? Icons.videocam : Icons.call,
                            size: 13,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$subtitle · ${entry.timeAgo(bn)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isMissed
                                    ? Colors.red.withValues(alpha: 0.8)
                                    : secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Redial button
                IconButton(
                  onPressed: () => _redial(entry, uid),
                  icon: Icon(
                    entry.isVideoCall ? Icons.videocam : Icons.call,
                    color: primaryMaroon,
                    size: 24,
                  ),
                  tooltip: bn ? 'আবার কল' : 'Call back',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OPEN CHAT SCREEN
  // ============================================================
  void _openChat(CallHistoryEntry entry, String uid) {
    final otherId = entry.otherUserId(uid);
    final otherName = entry.otherUserName(uid);
    final otherPhoto = entry.otherUserPhoto(uid);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          isBangla: widget.isBangla,
          otherUserId: otherId,
          otherUserName: otherName,
          otherUserPhoto: otherPhoto,
        ),
      ),
    );
  }

  // ============================================================
  // REDIAL
  // ============================================================
  Future<void> _redial(CallHistoryEntry entry, String uid) async {
    final otherId = entry.otherUserId(uid);
    final channelName = _generateCallRoomId(uid, otherId);

    final callId = await CallService.startCall(
      channelName: channelName,
      receiverId: otherId,
      receiverName: entry.otherUserName(uid),
      receiverPhoto: entry.otherUserPhoto(uid),
      isVideoCall: entry.isVideoCall,
    );

    if (!mounted || callId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          isBangla: widget.isBangla,
          channelName: channelName,
          otherUserName: entry.otherUserName(uid),
          otherUserPhoto: entry.otherUserPhoto(uid),
          isVideoCall: entry.isVideoCall,
          isCaller: true,
          callId: callId,
        ),
      ),
    );
  }

  String _generateCallRoomId(String a, String b) {
    final ids = [a, b]..sort();
    final combined = '${ids[0]}_${ids[1]}';
    int hash = 0x811c9dc5;
    for (int i = 0; i < combined.length; i++) {
      hash ^= combined.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'js_${hash.toRadixString(36).padLeft(7, '0')}';
  }

  // ============================================================
  // OPTIONS (long press)
  // ============================================================
  void _showOptions(CallHistoryEntry entry) {
    final bn = widget.isBangla;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(bn ? 'এই কল মুছুন' : 'Delete this call'),
              onTap: () {
                Navigator.pop(context);
                CallHistoryService.deleteEntry(entry.callId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================
  void _confirmClearAll() {
    final bn = widget.isBangla;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(bn ? 'সব কল মুছবেন?' : 'Clear all calls?'),
        content: Text(
          bn
              ? 'সব কল হিস্ট্রি মুছে ফেলা হবে। এই কাজ ফিরানো যাবে না।'
              : 'All call history will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(bn ? 'বাতিল' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await CallHistoryService.clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(bn ? 'মুছুন' : 'Clear'),
          ),
        ],
      ),
    );
  }
}
