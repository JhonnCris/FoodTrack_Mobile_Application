import 'package:flutter/foundation.dart';

import '../data/food_repository.dart';
import '../models/food.dart';

class FoodViewModel extends ChangeNotifier {
  FoodViewModel(this._repo) {
    load();
  }
  final FoodRepository _repo;
  String _query = '', _category = 'All';
  List<Food> _foods = [], _results = [];
  bool _loading = true;
  String? _error;
  String get query => _query;
  String get category => _category;
  List<Food> get foods => List.unmodifiable(_foods);
  List<Food> get results => _results;
  bool get loading => _loading;
  String? get error => _error;
  List<String> get categories => [
    'All',
    ..._foods.map((f) => f.category).toSet(),
  ];

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _foods = await _repo.loadFoods();
      _refresh();
    } catch (_) {
      _error = 'Unable to load foods.';
    }
    _loading = false;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    _refresh();
    notifyListeners();
  }

  void setCategory(String c) {
    _category = c;
    _refresh();
    notifyListeners();
  }

  void _refresh() {
    final q = _query.trim().toLowerCase();
    _results = _foods
        .where(
          (f) =>
              (q.isEmpty || f.name.toLowerCase().contains(q)) &&
              (_category == 'All' || f.category == _category),
        )
        .toList();
  }

  Future<Food> addCustom({
    required String name,
    required String category,
    required String servingLabel,
    required String description,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    double fiber = 0,
    double sugar = 0,
    double sodium = 0,
  }) async {
    final food = await _repo.addCustom(
      name: name,
      category: category,
      servingLabel: servingLabel,
      description: description,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sugar: sugar,
      sodium: sodium,
    );
    _foods = [..._foods, food];
    _refresh();
    notifyListeners();
    return food;
  }
}
