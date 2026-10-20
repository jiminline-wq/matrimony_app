import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/colors.dart';
import '../services/notification_service.dart';
import '../models/user_profile.dart';
import 'user_profile_view_screen.dart';
import 'home_screen.dart';

// ============================================================
// NOTIFICATION CENTER SCREEN
// ============================================================

class NotificationCenterScreen extends StatefulWidget {
  final bool isBangla;

  const NotificationCenterScreen({super.key, required this.isBangla});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    // Screen খোলার ২ সেকেন্ড পর সব read mark করি
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) NotificationService.markAllAsRead();
    });
  }

  // ============================================================
  // NOTIFICATION TAP HANDLER
  // Type অনুযায়ী specific screen এ navigate
  // ============================================================
  Future<void> _handleTap(AppNotification notif) async {
    // Mark as read
    await NotificationService.markAsRead(notif.id);

    if (!mounted) return;

    switch (notif.type) {
      case 'like':
        // Like notification → liker এর profile view
        if (notif.fromUid.isNotEmpty) {
          await _openUserProfile(notif.fromUid);
        }
        break;

      case 'match':
        // Match notification → Matches tab (Home screen index 3)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HomeScreen(isBangla: widget.isBangla, initialIndex: 3),
          ),
        );
        break;

      case 'message':
        // Message notification → sender এর profile view
        // (সেখান থেকে user "Message" button tap করে chat করতে পারবে)
        if (notif.fromUid.isNotEmpty) {
          await _openUserProfile(notif.fromUid);
        }
        break;

      default:
        // অজানা type → fromUid থাকলে profile view
        if (notif.fromUid.isNotEmpty) {
          await _openUserProfile(notif.fromUid);
        }
        break;
    }
  }

  // ============================================================
  // OPEN USER PROFILE
  // ============================================================
  Future<void> _openUserProfile(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        _showMessage(
          widget.isBangla ? 'প্রোফাইল পাওয়া যায়নি' : 'Profile not found',
        );
        return;
      }

      if (!mounted) return;

      final profile = UserProfile.fromMap(doc.data()!, docId: doc.id);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserProfileViewScreen(isBangla: widget.isBangla, user: profile),
        ),
      );
    } catch (e) {
      _showMessage(widget.isBangla ? 'লোড করা যায়নি' : 'Could not load');
    }
  }

  // ============================================================
  // SHOW MESSAGE
  // ============================================================
  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: deepMaroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================
  Future<void> _clearAll() async {
    final bn = widget.isBangla;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          bn ? 'সব মুছবেন?' : 'Clear all?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          bn
              ? 'সব notification মুছে যাবে। এটা undo করা যাবে না।'
              : 'All notifications will be deleted. This cannot be undone.',
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
              bn ? 'মুছুন' : 'Delete',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await NotificationService.deleteAll();

    if (!mounted) return;
    _showMessage(bn ? 'সব মুছে ফেলা হয়েছে' : 'All cleared');
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
        iconTheme: const IconThemeData(color: deepMaroon),
        title: Text(
          bn ? 'বিজ্ঞপ্তি' : 'Notifications',
          style: const TextStyle(
            color: deepMaroon,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined, color: primaryMaroon),
            tooltip: bn ? 'সব মুছুন' : 'Clear all',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.streamNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                bn ? 'লোড করা যায়নি' : 'Could not load',
                style: const TextStyle(color: secondaryText),
              ),
            );
          }

          final list = snapshot.data ?? [];

          if (list.isEmpty) {
            return _buildEmpty(bn);
          }

          return RefreshIndicator(
            color: primaryMaroon,
            onRefresh: () async {
              // Stream auto-refreshes
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) => _buildNotificationTile(list[i], bn),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmpty(bool bn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: lightMaroon,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 50,
                color: primaryMaroon,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              bn ? 'এখনো কোনো notification নেই' : 'No notifications yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: mainText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bn
                  ? 'কেউ like করলে, match হলে বা message পাঠালে এখানে দেখতে পাবেন।'
                  : 'When someone likes, matches or messages you, you\'ll see it here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION TILE
  // ============================================================
  Widget _buildNotificationTile(AppNotification notif, bool bn) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        NotificationService.delete(notif.id);
      },
      child: Material(
        color: notif.isRead
            ? Colors.transparent
            : lightMaroon.withValues(alpha: 0.35),
        child: InkWell(
          onTap: () => _handleTap(notif),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _buildAvatar(notif),

                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notif.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: mainText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notif.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _timeAgo(notif.createdAt, bn),
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          // Tap hint
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: secondaryText.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================
  Widget _buildAvatar(AppNotification notif) {
    Widget? photo;

    if (notif.fromPhotoUrl.isNotEmpty) {
      photo = ClipOval(
        child: Image.network(
          notif.fromPhotoUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _iconAvatar(_typeIcon(notif.type), _typeColor(notif.type)),
        ),
      );
    } else {
      photo = _iconAvatar(_typeIcon(notif.type), _typeColor(notif.type));
    }

    // Type badge
    IconData? badgeIcon;
    Color? badgeColor;

    switch (notif.type) {
      case 'like':
        badgeIcon = Icons.favorite;
        badgeColor = Colors.pink;
        break;
      case 'match':
        badgeIcon = Icons.celebration;
        badgeColor = Colors.orange;
        break;
      case 'message':
        badgeIcon = Icons.chat_bubble;
        badgeColor = Colors.blue;
        break;
    }

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryMaroon.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: photo,
            ),
          ),
          if (badgeIcon != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(badgeIcon, size: 11, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconAvatar(IconData icon, Color color) {
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(child: Icon(icon, size: 24, color: color)),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'match':
        return Icons.celebration;
      case 'message':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'like':
        return Colors.pink;
      case 'match':
        return Colors.orange;
      case 'message':
        return Colors.blue;
      default:
        return primaryMaroon;
    }
  }

  // ============================================================
  // TIME AGO
  // ============================================================
  String _timeAgo(DateTime? dt, bool bn) {
    if (dt == null) return bn ? 'এইমাত্র' : 'Just now';

    final diff = DateTime.now().difference(dt);

    if (diff.inSeconds < 60) {
      return bn ? 'এইমাত্র' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      return bn ? '${diff.inMinutes} মিনিট আগে' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return bn ? '${diff.inHours} ঘণ্টা আগে' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return bn ? '${diff.inDays} দিন আগে' : '${diff.inDays}d ago';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
