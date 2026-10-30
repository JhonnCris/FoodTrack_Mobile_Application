import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/food_repository.dart';
import 'package:foodtrack/data/meal_repository.dart';
import 'package:foodtrack/models/daily_nutrition.dart';
import 'package:foodtrack/models/food.dart';
import 'package:foodtrack/models/meal_entry.dart';
import 'package:foodtrack/viewmodels/diary_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MealRepositoryFake implements MealRepository {
  _MealRepositoryFake(this.currentUserId);

  final String? Function() currentUserId;
  final Map<String, List<MealEntry>> entriesByUser = {};
  final removeRequests = <Completer<void>>[];
  final removedUserIds = <String>[];

  @override
  Future<List<MealEntry>> loadToday(String timezone) async =>
      entriesByUser[currentUserId()] ?? [];

  @override
  Future<List<DailyNutrition>> loadNutritionSummary({
    required String timezone,
    required int days,
  }) async => [];

  @override
  Future<void> remove(String id, {required String userId}) {
    removedUserIds.add(userId);
    final request = Completer<void>();
    removeRequests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FoodRepositoryFake implements FoodRepository {
  @override
  Future<List<Food>> loadFavorites() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Food _food(String id) => Food(
  id: id,
  name: id,
  category: 'Test',
  emoji: '🍽️',
  servingLabel: '1 serving',
  calories: 100,
  protein: 10,
  carbs: 10,
  fat: 5,
);

MealEntry _entry(String id) => MealEntry(
  id: id,
  food: _food('$id-food'),
  type: MealType.lunch,
  servings: 1,
  date: DateTime(2026, 10, 30),
);

Future<void> _settleLoads() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test(
    'does not restore a removed meal into another account after failure',
    () async {
      var activeUserId = 'account-a';
      final meals = _MealRepositoryFake(() => activeUserId)
        ..entriesByUser['account-a'] = [_entry('meal-a')]
        ..entriesByUser['account-b'] = [];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final viewModel = DiaryViewModel(
        meals,
        _FoodRepositoryFake(),
        client,
        currentUserId: () => activeUserId,
      );

      viewModel.setUserId('account-a');
      await _settleLoads();
      expect(viewModel.entries.map((entry) => entry.id), ['meal-a']);

      final removeResult = viewModel.remove('meal-a');
      expect(viewModel.entries, isEmpty);
      expect(meals.removedUserIds, ['account-a']);

      activeUserId = 'account-b';
      viewModel.setUserId('account-b');
      await _settleLoads();
      meals.removeRequests.single.completeError(StateError('Delete failed'));
      expect(await removeResult, isFalse);

      expect(viewModel.entries, isEmpty);
      viewModel.dispose();
      client.dispose();
    },
  );

  test('restores a removed meal after a same-account delete failure', () async {
    var activeUserId = 'account-a';
    final meals = _MealRepositoryFake(() => activeUserId)
      ..entriesByUser['account-a'] = [_entry('meal-a')];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final viewModel = DiaryViewModel(
      meals,
      _FoodRepositoryFake(),
      client,
      currentUserId: () => activeUserId,
    );

    viewModel.setUserId('account-a');
    await _settleLoads();
    final removeResult = viewModel.remove('meal-a');
    meals.removeRequests.single.completeError(StateError('Delete failed'));

    expect(await removeResult, isFalse);
    expect(viewModel.entries.map((entry) => entry.id), ['meal-a']);
    viewModel.dispose();
    client.dispose();
  });
}
