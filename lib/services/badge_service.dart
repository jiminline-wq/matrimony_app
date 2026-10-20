import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// BADGE SERVICE
// ============================================================

class BadgeService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Stream<int> streamNewMatchCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('matches')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snap) {
          final yesterday = DateTime.now().subtract(const Duration(hours: 24));
          int count = 0;

          for (final doc in snap.docs) {
            final data = doc.data();
            final createdAt = data['createdAt'] as Timestamp?;
            if (createdAt == null) continue;
            if (createdAt.toDate().isAfter(yesterday)) {
              count++;
            }
          }
          return count;
        });
  }

  static Stream<int> streamUnreadChatCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('chats')
        .where('users', arrayContains: uid)
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final counts = Map<String, dynamic>.from(
              data['unreadCounts'] ?? {},
            );
            final n = (counts[uid] as num?)?.toInt() ?? 0;
            total += n;
          }
          return total;
        });
  }
}

// ============================================================
// BADGED ICON WIDGET
// ============================================================

class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color iconColor;
  final Color badgeColor;

  const BadgedIcon({
    super.key,
    required this.icon,
    required this.count,
    this.iconColor = Colors.grey,
    this.badgeColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon, color: iconColor);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor),
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
