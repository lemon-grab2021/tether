import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/circles_provider.dart';

class JoinCircleDialog extends StatefulWidget {
  const JoinCircleDialog({super.key});

  @override
  State<JoinCircleDialog> createState() => _JoinCircleDialogState();
}

class _JoinCircleDialogState extends State<JoinCircleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final circlesProvider = context.read<CirclesProvider>();
      await circlesProvider.joinCircle(_inviteCodeController.text.trim());

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to join circle: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Circle'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _inviteCodeController,
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            border: OutlineInputBorder(),
            hintText: 'Enter invite code',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter an invite code';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleJoin,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Join'),
        ),
      ],
    );
  }
}