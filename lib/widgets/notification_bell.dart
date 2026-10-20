import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../services/notification_service.dart';
import '../screens/notification_center_screen.dart';

// ============================================================
// NOTIFICATION BELL ICON
// AppBar এ রাখলে unread badge দেখাবে
// ============================================================

class NotificationBell extends StatelessWidget {
  final bool isBangla;
  final Color? iconColor;

  const NotificationBell({super.key, required this.isBangla, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.streamUnreadCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        final color = iconColor ?? deepMaroon;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: color),
              tooltip: isBangla ? 'বিজ্ঞপ্তি' : 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationCenterScreen(isBangla: isBangla),
                  ),
                );
              },
            ),
            if (unread > 0)
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
                    unread > 99 ? '99+' : '$unread',
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
