import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/food_repository.dart';
import '../models/food.dart';

class FoodViewModel extends ChangeNotifier {
  FoodViewModel(this._repo);

  static const _pageSize = 50;

  final FoodRepository _repo;
  String _query = '', _category = 'All';
  List<Food> _foods = [];
  List<String> _categories = ['All'];
  String? _userId;
  int _loadGeneration = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _categoriesLoaded = false;
  String? _error;
  Timer? _searchTimer;

  String get query => _query;
  String get category => _category;
  List<Food> get foods => List.unmodifiable(_foods);
  List<Food> get results => List.unmodifiable(_foods);
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  List<String> get categories => List.unmodifiable(_categories);

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _searchTimer?.cancel();
    _loadGeneration++;
    _foods = [];
    _categories = ['All'];
    _categoriesLoaded = false;
    _error = null;
    _hasMore = false;
    _loadingMore = false;
    _loading = userId != null;
    notifyListeners();
    if (userId != null) {
      unawaited(load());
    }
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    final generation = ++_loadGeneration;
    _searchTimer?.cancel();
    _foods = [];
    _hasMore = false;
    _loading = true;
    _loadingMore = false;
    _error = null;
    notifyListeners();

    try {
      final pageFuture = _repo.loadFoods(
        search: _query,
        category: _category == 'All' ? null : _category,
        limit: _pageSize,
      );
      final categoriesFuture = _categoriesLoaded
          ? Future<List<String>>.value(_categories.skip(1).toList())
          : _repo.loadCategories();
      final results = await Future.wait<Object>([pageFuture, categoriesFuture]);
      if (_userId != userId || _loadGeneration != generation) return;
      final page = results[0] as List<Food>;
      final categories = results[1] as List<String>;
      _foods = page;
      _hasMore = page.length == _pageSize;
      _categories = ['All', ...categories];
      _categoriesLoaded = true;
    } catch (_) {
      if (_userId != userId || _loadGeneration != generation) return;
      _error = 'Unable to load foods.';
    } finally {
      if (_userId == userId && _loadGeneration == generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final userId = _userId;
    if (userId == null || _loading || _loadingMore || !_hasMore) return;
    final generation = _loadGeneration;
    final offset = _foods.length;
    _loadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repo.loadFoods(
        search: _query,
        category: _category == 'All' ? null : _category,
        offset: offset,
        limit: _pageSize,
      );
      if (_userId != userId || _loadGeneration != generation) return;
      _foods = [..._foods, ...page];
      _hasMore = page.length == _pageSize;
    } catch (_) {
      if (_userId != userId || _loadGeneration != generation) return;
      _error = 'Unable to load more foods.';
    } finally {
      if (_userId == userId && _loadGeneration == generation) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    _searchTimer?.cancel();
    _loadGeneration++;
    _foods = [];
    _hasMore = false;
    _loadingMore = false;
    _loading = _userId != null;
    _error = null;
    notifyListeners();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(load());
    });
  }

  void setCategory(String category) {
    if (_category == category) return;
    _category = category;
    unawaited(load());
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
    final userId = _userId;
    if (userId == null) {
      throw StateError('You must be signed in to create a food.');
    }
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
    if (_userId == userId &&
        (_category == 'All' || _category == food.category) &&
        (_query.isEmpty ||
            food.name.toLowerCase().contains(_query.toLowerCase()))) {
      unawaited(load());
    }
    return food;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }
}
