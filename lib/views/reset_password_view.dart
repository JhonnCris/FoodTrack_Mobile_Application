import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../viewmodels/session_viewmodel.dart';

class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final password = _password.text;
    if (password.length < 6) {
      _showMessage('Your new password must have at least 6 characters.');
      return;
    }
    if (password != _confirmation.text) {
      _showMessage('The passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      final session = context.read<SessionViewModel>();
      await session.updatePassword(password);
      await session.finishPasswordRecovery();
      if (mounted)
        _showMessage(
          'Password updated. Please sign in with your new password.',
        );
    } on AuthException catch (error) {
      _showMessage(friendlyAuthError(error));
    } catch (_) {
      _showMessage(
        'Unable to update your password. Please try the recovery link again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_reset, size: 64),
              const SizedBox(height: 16),
              Text(
                'Set a new password',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a new password for your FoodTrack account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: true,
                autofocus: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                onSubmitted: (_) => _busy ? null : _savePassword(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _savePassword,
                child: Text(_busy ? 'Updating...' : 'Update password'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
