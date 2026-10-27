import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._auth) { _sub = _auth.states.listen((_) { _loading = false; notifyListeners(); }); _loading = false; }
  final AuthRepository _auth;
  late final StreamSubscription _sub;
  bool _loading = true;
  bool get loading => _loading;
  bool get signedIn => _auth.currentUser != null;
  Future<AuthResponse> signIn(String e, String p) => _auth.signIn(e, p);
  Future<AuthResponse> signUp(String e, String p) => _auth.signUp(e, p);
  Future<void> sendPasswordRecovery(String email) => _auth.sendPasswordRecovery(email);
  Future<void> resendConfirmation(String email) => _auth.resendConfirmation(email);
  Future<void> signOut() => _auth.signOut();
  @override void dispose() { _sub.cancel(); super.dispose(); }
}
