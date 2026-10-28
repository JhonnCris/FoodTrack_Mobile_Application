import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._auth) {
    _sub = _auth.states.listen(_onAuthStateChanged);
    _loading = false;
  }
  final AuthRepository _auth;
  late final StreamSubscription<AuthState> _sub;
  bool _loading = true;
  bool _passwordRecoveryInProgress = false;
  bool get loading => _loading;
  bool get signedIn => _auth.currentUser != null;
  bool get passwordRecoveryInProgress => _passwordRecoveryInProgress;
  Future<AuthResponse> signIn(String e, String p) => _auth.signIn(e, p);
  Future<AuthResponse> signUp(String e, String p) => _auth.signUp(e, p);
  Future<void> sendPasswordRecovery(String email) => _auth.sendPasswordRecovery(email);
  Future<void> resendConfirmation(String email) => _auth.resendConfirmation(email);
  Future<void> signOut() => _auth.signOut();
  Future<void> updatePassword(String password) => _auth.updatePassword(password);

  Future<void> finishPasswordRecovery() async {
    _passwordRecoveryInProgress = false;
    notifyListeners();
    await signOut();
  }

  void _onAuthStateChanged(AuthState state) {
    _loading = false;
    if (state.event == AuthChangeEvent.passwordRecovery) {
      _passwordRecoveryInProgress = true;
    } else if (state.event == AuthChangeEvent.signedOut) {
      _passwordRecoveryInProgress = false;
    }
    notifyListeners();
  }

  @override void dispose() { _sub.cancel(); super.dispose(); }
}
