import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../viewmodels/session_viewmodel.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      _showMessage('Enter a valid email and a password with at least 6 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      final session = context.read<SessionViewModel>();
      final response = _signUp
          ? await session.signUp(email, password)
          : await session.signIn(email, password);
      if (_signUp && response.session == null && mounted) {
        _showMessage('Account created. Check your email to confirm it, then sign in.');
      }
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to reach Supabase. Check your internet connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRecovery() => _sendEmailAction(
        (session, email) => session.sendPasswordRecovery(email),
        'If an account exists, a password-reset email has been sent.',
      );

  Future<void> _resendConfirmation() => _sendEmailAction(
        (session, email) => session.resendConfirmation(email),
        'If the account needs confirmation, a new email has been sent.',
      );

  Future<void> _sendEmailAction(
    Future<void> Function(SessionViewModel session, String email) action,
    String successMessage,
  ) async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showMessage('Enter your email address first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await action(context.read<SessionViewModel>(), email);
      _showMessage(successMessage);
    } on AuthException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to send the email. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(
                  'assets/images/branding/foodtrack_logo.webp',
                  width: 128,
                  height: 128,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(
                  _signUp ? 'Create your account' : 'Welcome back',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Please wait…' : _signUp ? 'Sign up' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _signUp = !_signUp),
                  child: Text(_signUp
                      ? 'Already have an account? Sign in'
                      : 'Need an account? Sign up'),
                ),
                if (!_signUp) ...[
                  TextButton(
                    onPressed: _busy ? null : _sendRecovery,
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _resendConfirmation,
                    child: const Text('Resend confirmation email'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
}
