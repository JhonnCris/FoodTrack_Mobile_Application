import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/food_repository.dart';
import 'package:foodtrack/models/food.dart';
import 'package:foodtrack/viewmodels/food_viewmodel.dart';

class _FoodRepositoryFake implements FoodRepository {
  final requests = <Completer<List<Food>>>[];
  final offsets = <int>[];
  final searches = <String?>[];
  final categories = <String?>[];

  @override
  Future<List<Food>> loadFoods({
    String? search,
    String? category,
    int offset = 0,
    int limit = 50,
  }) {
    searches.add(search);
    categories.add(category);
    offsets.add(offset);
    final request = Completer<List<Food>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<String>> loadCategories() async => ['Test', 'Other'];

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

  test(
    'loads catalog pages and applies search and category remotely',
    () async {
      final repository = _FoodRepositoryFake();
      final viewModel = FoodViewModel(repository);
      viewModel.setUserId('account-a');

      repository.requests[0].complete(
        List.generate(50, (index) => _food('food-$index')),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.foods, hasLength(50));
      expect(viewModel.hasMore, isTrue);

      final nextPage = viewModel.loadMore();
      expect(repository.offsets.last, 50);
      repository.requests[1].complete([_food('food-50')]);
      await nextPage;
      expect(viewModel.foods, hasLength(51));
      expect(viewModel.hasMore, isFalse);

      viewModel.setQuery('apple');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repository.searches.last, 'apple');
      expect(repository.offsets.last, 0);
      repository.requests[2].complete([]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      viewModel.setCategory('Test');
      expect(repository.categories.last, 'Test');
      repository.requests[3].complete([]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.category, 'Test');
      expect(repository.searches.last, 'apple');
      viewModel.dispose();
    },
  );
}
