import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final double? fontSize;

  const AppAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.backgroundColor = const Color(0xFFEDE9FE),
    this.textColor = const Color(0xFF5B21B6),
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final safeName = name.trim().isNotEmpty ? name.trim() : '?';
    final initial = safeName[0].toUpperCase();
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final resolvedFontSize = fontSize ?? radius * 0.8;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: hasAvatar
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: resolvedFontSize,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: resolvedFontSize,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
    );
  }
}