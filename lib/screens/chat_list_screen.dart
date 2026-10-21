import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb এর জন্য

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../widgets/verified_badge.dart';
import 'chat_screen.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ============================================================
// CHAT LIST SCREEN — Delete + Archive
// ============================================================

class ChatListScreen extends StatefulWidget {
  final bool isBangla;

  const ChatListScreen({super.key, required this.isBangla});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  String? _myUid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        iconTheme: const IconThemeData(color: deepMaroon),
        title: Text(
          bn ? 'বার্তা' : 'Messages',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryMaroon,
          unselectedLabelColor: secondaryText,
          indicatorColor: primaryMaroon,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 16),
                  const SizedBox(width: 6),
                  Text(bn ? 'সব' : 'All'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.archive_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(bn ? 'আর্কাইভ' : 'Archived'),
                ],
              ),
            ),
          ],
        ),
      ),
      // ✅ LayoutBuilder দিয়ে মোবাইল/ওয়েব আলাদা করা হলো
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;

          return Column(
            children: [
              Expanded(
                child: _myUid == null
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryMaroon))
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chats')
                            .where('users', arrayContains: _myUid)
                            .orderBy('lastMessageTime', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: primaryMaroon),
                            );
                          }

                          if (snapshot.hasError) {
                            debugPrint(
                                '❌ Chats stream error: ${snapshot.error}');
                            return Center(
                              child: Text(
                                bn ? 'লোড করা যায়নি' : 'Could not load',
                                style: const TextStyle(color: secondaryText),
                              ),
                            );
                          }
                          final allChats = snapshot.data?.docs ?? [];

                          // ✅ Active Chats (Archived নয়, Deleted নয়)
                          final activeChats = allChats.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isDeleted =
                                data['deletedFor.$_myUid'] == true;
                            final isArchived =
                                data['archivedFor.$_myUid'] == true;
                            return !isDeleted && !isArchived;
                          }).toList();

                          // ✅ Archived Chats (Archived, Deleted নয়)
                          final archivedChats = allChats.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final isDeleted =
                                data['deletedFor.$_myUid'] == true;
                            final isArchived =
                                data['archivedFor.$_myUid'] == true;
                            return !isDeleted && isArchived;
                          }).toList();

                          debugPrint('📋 [ChatList] total=${allChats.length}, '
                              'active=${activeChats.length}, '
                              'archived=${archivedChats.length}');

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildListFromDocs(
                                  activeChats, bn, false, isDesktop),
                              _buildListFromDocs(
                                  archivedChats, bn, true, isDesktop),
                            ],
                          );
                        },
                      ),
              ),
              // ✅ AdMob শুধু মোবাইলে
              if (!kIsWeb)
                const SafeArea(
                  top: false,
                  child:
                      BannerAdWidget(placementId: AdConfig.placementChatList),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD LIST — Responsive
  // ============================================================
  Widget _buildListFromDocs(
    List<QueryDocumentSnapshot> chats,
    bool bn,
    bool archived,
    bool isDesktop,
  ) {
    if (chats.isEmpty) return _buildEmpty(bn, archived);

    final listWidget = ListView.separated(
      shrinkWrap: isDesktop,
      physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 90,
        color: primaryMaroon.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, i) => _buildChatTile(chats[i], bn, archived),
    );

    // ✅ ওয়েবে সুন্দর ড্যাশবোর্ড লুক
    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900), // ম্যাক্স উইডথ
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: listWidget,
              ),
            ),
          ),
        ),
      );
    }

    // মোবাইল লিস্ট
    return listWidget;
  }

  // ============================================================
  // CHAT TILE
  // ============================================================
  Widget _buildChatTile(DocumentSnapshot chatDoc, bool bn, bool isArchivedTab) {
    final data = chatDoc.data() as Map<String, dynamic>;
    final users = List<String>.from(data['users'] ?? []);
    final lastMessage = (data['lastMessage'] ?? '').toString();
    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
    final lastSenderId = data['lastSenderId'] as String? ?? '';
    final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
    final unread = (unreadCounts[_myUid] as num?)?.toInt() ?? 0;

    final otherUid = users.firstWhere((u) => u != _myUid, orElse: () => '');

    if (otherUid.isEmpty) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) {
          return const SizedBox();
        }

        final userData = userSnap.data!.data() as Map<String, dynamic>;

        if (userData['isDeactivated'] == true) {
          return const SizedBox();
        }

        final otherUser = UserProfile.fromMap(
          userData,
          docId: userSnap.data!.id,
        );

        return _buildTileContent(
          chatId: chatDoc.id,
          otherUser: otherUser,
          lastMessage: lastMessage,
          lastMessageTime: lastMessageTime,
          isMyLastMessage: lastSenderId == _myUid,
          unread: unread,
          bn: bn,
          isArchived: isArchivedTab,
        );
      },
    );
  }

  Widget _buildTileContent({
    required String chatId,
    required UserProfile otherUser,
    required String lastMessage,
    required Timestamp? lastMessageTime,
    required bool isMyLastMessage,
    required int unread,
    required bool bn,
    required bool isArchived,
  }) {
    final hasUnread = unread > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChat(otherUser),
        onLongPress: () => _showChatMenu(chatId, otherUser, isArchived, bn),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(otherUser),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  otherUser.name.isEmpty
                                      ? (bn ? 'নাম নেই' : 'No name')
                                      : otherUser.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: hasUnread
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: mainText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (otherUser.isVerified) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(size: 14),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatChatTime(lastMessageTime, bn),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w500,
                            color: hasUnread
                                ? primaryMaroon
                                : secondaryText.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMyLastMessage)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.done_all,
                              size: 14,
                              color: primaryMaroon.withValues(alpha: 0.55),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastMessage.isEmpty
                                ? (bn ? 'কথা শুরু করুন' : 'Start conversation')
                                : lastMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread ? mainText : secondaryText,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [primaryGold, primaryMaroon],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
  // CHAT MENU (Long press)
  // ============================================================
  void _showChatMenu(
    String chatId,
    UserProfile otherUser,
    bool isArchived,
    bool bn,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: lightMaroon,
                        backgroundImage: otherUser.photoUrl.isNotEmpty
                            ? NetworkImage(otherUser.photoUrl)
                            : null,
                        child: otherUser.photoUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: primaryMaroon,
                                size: 20,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          otherUser.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: mainText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ListTile(
                  leading: Icon(
                    isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    color: primaryMaroon,
                  ),
                  title: Text(
                    isArchived
                        ? (bn ? 'আনআর্কাইভ করুন' : 'Unarchive')
                        : (bn ? 'আর্কাইভ করুন' : 'Archive'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    isArchived
                        ? (bn ? 'সব বার্তায় ফিরে যাবে' : 'Move back to All')
                        : (bn ? 'আর্কাইভে সরিয়ে নিন' : 'Move to Archived'),
                    style: const TextStyle(fontSize: 12, color: secondaryText),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final success =
                        await ChatService.archiveChat(chatId, !isArchived);

                    if (!mounted) return;

                    if (success) {
                      _showSnack(
                        isArchived
                            ? (bn ? 'আনআর্কাইভ হয়েছে' : 'Unarchived')
                            : (bn ? 'আর্কাইভ হয়েছে' : 'Archived'),
                      );
                    } else {
                      _showSnack(
                        bn ? 'আর্কাইভ করা যায়নি' : 'Could not archive',
                        isError: true,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    bn ? 'ডিলিট করুন' : 'Delete',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.redAccent,
                    ),
                  ),
                  subtitle: Text(
                    bn
                        ? 'শুধু আপনার list থেকে মুছবে'
                        : 'Remove only from your list',
                    style: const TextStyle(fontSize: 12, color: secondaryText),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _confirmDelete(chatId, otherUser, bn);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CONFIRM DELETE
  // ============================================================
  Future<void> _confirmDelete(
    String chatId,
    UserProfile otherUser,
    bool bn,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          bn ? 'ডিলিট করবেন?' : 'Delete Chat?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          bn
              ? '${otherUser.name} এর সাথে সব message আপনার list থেকে মুছে যাবে। '
                  'নতুন message এলে আবার চ্যাট ফিরে আসবে।'
              : 'All messages with ${otherUser.name} will be removed from '
                  'your list. Chat will return if a new message arrives.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              bn ? 'বাতিল' : 'Cancel',
              style: const TextStyle(color: secondaryText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              bn ? 'ডিলিট' : 'Delete',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ChatService.deleteChat(chatId);
    if (!mounted) return;

    if (success) {
      _showSnack(bn ? 'ডিলিট করা হয়েছে' : 'Chat deleted', isError: false);
    } else {
      _showSnack(bn ? 'ডিলিট করা যায়নি' : 'Could not delete', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : primaryMaroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================
  Widget _buildAvatar(UserProfile user) {
    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [primaryGold, primaryMaroon]),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: user.photoUrl.isNotEmpty
              ? Image.network(
                  user.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, color: primaryMaroon, size: 32),
                )
              : const Icon(Icons.person, color: primaryMaroon, size: 32),
        ),
      ),
    );
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================
  String _formatChatTime(Timestamp? ts, bool bn) {
    if (ts == null) return '';

    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return bn ? 'এইমাত্র' : 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return DateFormat('dd/MM/yy').format(dt);
  }

  // ============================================================
  // OPEN CHAT
  // ============================================================
  Future<void> _openChat(UserProfile otherUser) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          isBangla: widget.isBangla,
          otherUserId: otherUser.uid,
          otherUserName: otherUser.name,
          otherUserPhoto: otherUser.photoUrl,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmpty(bool bn, bool archived) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: lightMaroon,
                shape: BoxShape.circle,
              ),
              child: Icon(
                archived
                    ? Icons.archive_outlined
                    : Icons.chat_bubble_outline_rounded,
                size: 60,
                color: primaryMaroon,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              archived
                  ? (bn ? 'কোনো আর্কাইভ নেই' : 'No archived chats')
                  : (bn ? 'এখনো কোনো chat নেই' : 'No chats yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              archived
                  ? (bn
                      ? 'Long press করে chat আর্কাইভ করতে পারবেন'
                      : 'Long press a chat to archive it')
                  : (bn
                      ? 'ম্যাচ হলে বা কেউ message পাঠালে এখানে দেখা যাবে।'
                      : 'When you match or someone messages you, chats will appear here.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
