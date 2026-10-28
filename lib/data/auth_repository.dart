import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String friendlyAuthError(AuthException error) {
  final message = error.message.trim();
  final normalized = message.toLowerCase();

  if (normalized.contains('rate limit') ||
      normalized.contains('too many requests')) {
    return 'Too many emails or requests were made recently. Please wait a while '
        'before trying again, then check your inbox and spam folder.';
  }
  if (normalized.contains('invalid login credentials')) {
    return 'That email and password do not match. Check them or use “Forgot password?”.';
  }
  if (normalized.contains('email not confirmed')) {
    return 'Please confirm your email using the link we sent before signing in.';
  }
  if (normalized.contains('user already registered')) {
    return 'An account already uses this email. Try signing in or choose “Forgot password?”.';
  }
  if (normalized.contains('password should be at least')) {
    return 'Choose a longer password and try again.';
  }

  return message.isEmpty ? 'Authentication failed. Please try again.' : message;
}

class AuthRepository {
  static const _authRedirectUrl = 'foodtrack://auth';

  AuthRepository(this.client);
  final SupabaseClient client;
  Stream<AuthState> get states => client.auth.onAuthStateChange;
  User? get currentUser => client.auth.currentUser;
  Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);
  Future<AuthResponse> signUp(String email, String password) => client.auth
      .signUp(email: email, password: password, emailRedirectTo: _redirectUrl);
  Future<void> sendPasswordRecovery(String email) =>
      client.auth.resetPasswordForEmail(email, redirectTo: _redirectUrl);
  Future<UserResponse> updatePassword(String password) =>
      client.auth.updateUser(UserAttributes(password: password));
  Future<void> resendConfirmation(String email) => client.auth.resend(
    type: OtpType.signup,
    email: email,
    emailRedirectTo: _redirectUrl,
  );
  Future<void> signOut() => client.auth.signOut();

  /// Browser callbacks must return to the page that opened the email. Native
  /// builds use the registered custom scheme declared in Android and iOS.
  static String get _redirectUrl => kIsWeb ? Uri.base.origin : _authRedirectUrl;
}
