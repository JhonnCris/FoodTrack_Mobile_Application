import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  static const _authRedirectUrl = 'foodtrack://auth';

  AuthRepository(this.client);
  final SupabaseClient client;
  Stream<AuthState> get states => client.auth.onAuthStateChange;
  User? get currentUser => client.auth.currentUser;
  Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);
  Future<AuthResponse> signUp(String email, String password) =>
      client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _authRedirectUrl,
      );
  Future<void> sendPasswordRecovery(String email) =>
      client.auth.resetPasswordForEmail(email, redirectTo: _authRedirectUrl);
  Future<void> resendConfirmation(String email) => client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _authRedirectUrl,
      );
  Future<void> signOut() => client.auth.signOut();
}
