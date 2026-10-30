import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/food_repository.dart';
import 'package:foodtrack/models/food.dart';
import 'package:foodtrack/viewmodels/food_viewmodel.dart';

class _FoodRepositoryFake implements FoodRepository {
  final requests = <Completer<List<Food>>>[];

  @override
  Future<List<Food>> loadFoods() {
    final request = Completer<List<Food>>();
    requests.add(request);
    return request.future;
  }

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
  test(
    'discards stale food loads when the signed-in account changes',
    () async {
      final repository = _FoodRepositoryFake();
      final viewModel = FoodViewModel(repository);

      viewModel.setUserId('account-a');
      final accountARequest = repository.requests.single;
      viewModel.setUserId('account-b');
      final accountBRequest = repository.requests.last;

      accountBRequest.complete([_food('account-b-food')]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.foods.map((food) => food.id), ['account-b-food']);

      accountARequest.complete([_food('account-a-private-food')]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.foods.map((food) => food.id), ['account-b-food']);

      viewModel.dispose();
    },
  );
}
