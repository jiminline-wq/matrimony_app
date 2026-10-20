import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../screens/chat_list_screen.dart';

// ============================================================
// CHAT ICON BUTTON
// Unread badge সহ — AppBar এ ব্যবহারের জন্য
// ============================================================

class ChatIconButton extends StatelessWidget {
  final bool isBangla;
  final Color? iconColor;

  const ChatIconButton({super.key, required this.isBangla, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final color = iconColor ?? deepMaroon;

    if (myUid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalUnread = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final counts = Map<String, dynamic>.from(
              data['unreadCounts'] ?? {},
            );
            final n = (counts[myUid] as num?)?.toInt() ?? 0;
            totalUnread += n;
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, color: color),
              tooltip: isBangla ? 'বার্তা' : 'Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatListScreen(isBangla: isBangla),
                  ),
                );
              },
            ),
            if (totalUnread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    totalUnread > 99 ? '99+' : '$totalUnread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
