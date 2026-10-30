import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_export.dart';
import 'complete_paged_rows.dart';
import 'pending_profile_store.dart';

class AccountDeletionLocalCleanupException implements Exception {
  const AccountDeletionLocalCleanupException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'Account was deleted, but local pending data could not be removed: '
      '$cause';
}

class AccountRepository {
  AccountRepository(this._client, this._pendingProfileStore);

  final SupabaseClient _client;
  final PendingProfileStore _pendingProfileStore;

  static const _exportPageSize = 500;

  Future<String> exportAccountData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to export account data.');
    }

    void ensureSameAccount() {
      if (_client.auth.currentUser?.id != user.id) {
        throw StateError('The signed-in account changed during data export.');
      }
    }

    final profile = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    ensureSameAccount();

    final allergies = await _fetchRows(
      table: 'user_allergies',
      select: '*, allergens(code, display_name)',
      ownerColumn: 'user_id',
      userId: user.id,
      orderColumn: 'created_at',
      tieBreakerColumn: 'id',
    );
    final dislikes = await _fetchRows(
      table: 'user_disliked_foods',
      select: '*',
      ownerColumn: 'user_id',
      userId: user.id,
      orderColumn: 'created_at',
      tieBreakerColumn: 'id',
    );
    final favorites = await _fetchRows(
      table: 'user_favorites',
      select: '*, foods(*, food_allergens(*, allergens(*)), food_diet_tags(*))',
      ownerColumn: 'user_id',
      userId: user.id,
      orderColumn: 'created_at',
      tieBreakerColumn: 'food_id',
    );
    final customFoods = await _fetchRows(
      table: 'foods',
      select: '*, food_allergens(*, allergens(*)), food_diet_tags(*)',
      ownerColumn: 'created_by_user_id',
      userId: user.id,
      orderColumn: 'created_at',
      tieBreakerColumn: 'id',
    );
    final meals = await _fetchRows(
      table: 'meal_entries',
      select:
          '*, foods(*, food_allergens(*, allergens(*)), food_diet_tags(*)), '
          'meal_entry_nutrition(*)',
      ownerColumn: 'user_id',
      userId: user.id,
      orderColumn: 'logged_at',
      tieBreakerColumn: 'id',
    );
    final recommendations = await _fetchRows(
      table: 'recommendation_events',
      select: '*',
      ownerColumn: 'user_id',
      userId: user.id,
      orderColumn: 'created_at',
      tieBreakerColumn: 'id',
    );

    final pendingProfileWrite = await _pendingProfileStore.load(user.id);
    ensureSameAccount();

    return encodeAccountExport(
      userId: user.id,
      email: user.email,
      createdAt: user.createdAt,
      profile: profile,
      allergies: allergies,
      dislikes: dislikes,
      favorites: favorites,
      customFoods: customFoods,
      meals: meals,
      recommendations: recommendations,
      pendingProfileWrite: pendingProfileWrite?.toJson(),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRows({
    required String table,
    required String select,
    required String ownerColumn,
    required String userId,
    required String orderColumn,
    required String tieBreakerColumn,
  }) {
    void ensureSameAccount() {
      if (_client.auth.currentUser?.id != userId) {
        throw StateError('The signed-in account changed during data export.');
      }
    }

    return fetchCompletePagedRows<Map<String, dynamic>>(
      pageSize: _exportPageSize,
      ensureValid: ensureSameAccount,
      countRows: () async {
        return _client.from(table).count().eq(ownerColumn, userId);
      },
      fetchPage: (from, to) async {
        return _client
            .from(table)
            .select(select)
            .eq(ownerColumn, userId)
            .order(orderColumn)
            .order(tieBreakerColumn)
            .range(from, to);
      },
    );
  }

  Future<void> deleteAccount({required String password}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to delete an account.');
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError(
        'Password reauthentication is unavailable for this account.',
      );
    }

    await _client.auth.signInWithPassword(email: email, password: password);
    if (_client.auth.currentUser?.id != user.id) {
      throw StateError(
        'The signed-in account changed during reauthentication.',
      );
    }

    await _client.functions.invoke('delete-account');
    try {
      if (_client.auth.currentUser?.id == user.id) {
        await _client.auth.signOut();
      }
    } finally {
      try {
        await _pendingProfileStore.clearForUser(user.id);
      } catch (error) {
        throw AccountDeletionLocalCleanupException(error);
      }
    }
  }
}
