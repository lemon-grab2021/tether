import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notifications_provider.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.select<NotificationsProvider, int>(
      (provider) => provider.unreadCount,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );

            if (context.mounted) {
              await context
                  .read<NotificationsProvider>()
                  .refreshUnreadCount();
            }
          },
          splashRadius: 22,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF6B7280),
            size: 23,
          ),
        ),

        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6C5CFF),
                    Color(0xFFD66BEE),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CFF).withOpacity(0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}