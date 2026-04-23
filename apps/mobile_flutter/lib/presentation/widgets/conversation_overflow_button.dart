import 'package:flutter/material.dart';

enum ConversationMenuAction {
  pin,
  mute,
  delete,
}

class ConversationOverflowButton extends StatelessWidget {
  final VoidCallback? onPin;
  final VoidCallback? onMute;
  final VoidCallback onDelete;

  const ConversationOverflowButton({
    super.key,
    this.onPin,
    this.onMute,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ConversationMenuAction>(
      onSelected: (value) {
        switch (value) {
          case ConversationMenuAction.pin:
            onPin?.call();
            break;
          case ConversationMenuAction.mute:
            onMute?.call();
            break;
          case ConversationMenuAction.delete:
            onDelete();
            break;
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      color: Colors.white,
      elevation: 12,
      offset: const Offset(0, 10),
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF475569),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: ConversationMenuAction.pin,
          child: _MenuRow(
            icon: Icons.push_pin_outlined,
            label: 'Pin conversation',
          ),
        ),
        const PopupMenuItem(
          value: ConversationMenuAction.mute,
          child: _MenuRow(
            icon: Icons.notifications_off_outlined,
            label: 'Mute notifications',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: ConversationMenuAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete conversation',
            destructive: true,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool destructive;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFD92D20) : const Color(0xFF0F172A);

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}