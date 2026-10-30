import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/food_repository.dart';
import 'package:foodtrack/data/meal_repository.dart';
import 'package:foodtrack/models/daily_nutrition.dart';
import 'package:foodtrack/models/food.dart';
import 'package:foodtrack/models/meal_entry.dart';
import 'package:foodtrack/models/user_profile.dart';
import 'package:foodtrack/viewmodels/diary_viewmodel.dart';
import 'package:foodtrack/viewmodels/recommendation_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FoodRepositoryFake implements FoodRepository {
  final requests = <Completer<List<Food>>>[];

  @override
  Future<List<Food>> loadFoods({
    String? search,
    String? category,
    int offset = 0,
    int limit = 50,
  }) {
    final request = Completer<List<Food>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<Food>> loadAllFoods() => loadFoods();

  @override
  Future<List<String>> loadCategories() async => [];

  @override
  Future<List<Food>> loadFavorites() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MealRepositoryFake implements MealRepository {
  @override
  Future<List<MealEntry>> loadToday(String timezone) async => [];

  @override
  Future<List<DailyNutrition>> loadNutritionSummary({
    required String timezone,
    required int days,
  }) async => [];

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

void main() {
  test('discards stale recommendations after an account switch', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final foodRepository = _FoodRepositoryFake();
    final diary = DiaryViewModel(_MealRepositoryFake(), foodRepository, client);
    final viewModel = RecommendationViewModel(foodRepository, client);
    final profile = UserProfile()..goal = FitnessGoal.muscle;

    viewModel.setUserId('account-a');
    final accountAResult = viewModel.generate(
      profile,
      diary,
      trigger: 'manual',
    );
    final accountARequest = foodRepository.requests.single;

    viewModel.setUserId('account-b');
    final accountBResult = viewModel.generate(
      profile,
      diary,
      trigger: 'manual',
    );
    final accountBRequest = foodRepository.requests.last;
    accountBRequest.complete([_food('account-b-food')]);
    await accountBResult;
    expect(viewModel.items.map((item) => item.food.id), ['account-b-food']);

    accountARequest.complete([_food('account-a-private-food')]);
    await accountAResult;
    expect(viewModel.items.map((item) => item.food.id), ['account-b-food']);

    viewModel.dispose();
    diary.dispose();
    client.dispose();
  });
}
