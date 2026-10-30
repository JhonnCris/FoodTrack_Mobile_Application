import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/pending_profile_store.dart';
import 'package:foodtrack/data/profile_repository.dart';
import 'package:foodtrack/models/user_profile.dart';
import 'package:foodtrack/viewmodels/profile_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _ProfileRepositoryFake implements ProfileRepository {
  final requests = <String, List<Completer<UserProfile?>>>{};

  @override
  Future<UserProfile?> load({String? userId}) {
    final request = Completer<UserProfile?>();
    requests.putIfAbsent(userId!, () => []).add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settleAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('discards a delayed profile load after switching accounts', () async {
    var activeUserId = 'account-a';
    final authChanges = StreamController<void>.broadcast();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final repository = _ProfileRepositoryFake();
    final viewModel = ProfileViewModel(
      repository,
      client,
      PendingProfileStore.memory(),
      currentUserId: () => activeUserId,
      authStateChanges: authChanges.stream,
    );
    final accountARequest = repository.requests['account-a']!.single;

    activeUserId = 'account-b';
    authChanges.add(null);
    await _settleAsync();
    final accountBRequest = repository.requests['account-b']!.single;
    accountBRequest.complete(UserProfile(name: 'Account B'));
    await _settleAsync();
    expect(viewModel.profile.name, 'Account B');

    accountARequest.complete(UserProfile(name: 'Account A private profile'));
    await _settleAsync();
    expect(viewModel.profile.name, 'Account B');

    viewModel.dispose();
    await authChanges.close();
    client.dispose();
  });
}
