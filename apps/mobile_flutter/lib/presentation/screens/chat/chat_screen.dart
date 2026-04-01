import 'package:flutter/material.dart';
import '../../../data/models/circle.dart';

class ChatScreen extends StatelessWidget {
  final Circle circle;

  const ChatScreen({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
      ),
      body: const Center(
        child: Text('Chat screen coming next!'),
      ),
    );
  }
}