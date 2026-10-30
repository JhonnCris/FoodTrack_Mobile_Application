import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/food_repository.dart';
import '../data/meal_repository.dart';
import '../models/daily_nutrition.dart';
import '../models/food.dart';
import '../models/meal_entry.dart';

enum ReportRange {
  week('Week', 7),
  month('Month', 31);

  const ReportRange(this.label, this.days);
  final String label;
  final int days;
}

class DiaryViewModel extends ChangeNotifier {
  DiaryViewModel(
    this._meals,
    this._foods,
    this._client, {
    this._timezone = 'Asia/Manila',
    String? Function()? currentUserId,
  }) : _currentUserId = currentUserId ?? (() => _client.auth.currentUser?.id);
  final MealRepository _meals;
  final FoodRepository _foods;
  final SupabaseClient _client;
  final String? Function() _currentUserId;
  String _timezone;
  List<MealEntry> _entries = [];
  List<Food> _favoriteFoods = [];
  var _report = <DailyNutrition>[];
  Set<String> _favorites = {};
  bool _loading = true;
  String? _error;
  String? _userId;
  int _loadGeneration = 0;
  ReportRange _reportRange = ReportRange.week;
  bool _reportLoading = false;
  String? _reportError;
  List<MealEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  String? get error => _error;
  List<DailyNutrition> get reportNutrition => List.unmodifiable(_report);
  ReportRange get reportRange => _reportRange;
  bool get reportLoading => _reportLoading;
  String? get reportError => _reportError;
  List<MealEntry> entriesFor(MealType t) =>
      _entries.where((e) => e.type == t).toList();
  double get totalCalories => _entries.fold(0, (s, e) => s + e.calories);
  double get totalProtein => _entries.fold(0, (s, e) => s + e.protein);
  double get totalCarbs => _entries.fold(0, (s, e) => s + e.carbs);
  double get totalFat => _entries.fold(0, (s, e) => s + e.fat);
  double caloriesFor(MealType t) =>
      entriesFor(t).fold(0, (s, e) => s + e.calories);
  List<Food> get recentFoods {
    final seen = <String>{};
    return _entries.reversed
        .where((e) => seen.add(e.food.id))
        .map((e) => e.food)
        .toList();
  }

  bool isFavorite(Food f) => _favorites.contains(f.id);
  List<Food> get favoriteFoods => List.unmodifiable(_favoriteFoods);

  bool _isCurrentAccount(String userId, int generation) =>
      _userId == userId &&
      _currentUserId() == userId &&
      _loadGeneration == generation;

  void setTimezone(String value) {
    if (_timezone == value) return;
    _timezone = value;
    load();
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loadGeneration++;
    _entries = [];
    _favoriteFoods = [];
    _favorites = {};
    _report = [];
    _error = null;
    _reportError = null;
    _loading = userId != null;
    _reportLoading = false;
    notifyListeners();
    if (userId != null) load();
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    final generation = ++_loadGeneration;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await Future.wait([
        _meals.loadToday(_timezone),
        _foods.loadFavorites(),
      ]);
      if (_userId != userId || _loadGeneration != generation) return;
      _entries = result[0] as List<MealEntry>;
      _favoriteFoods = result[1] as List<Food>;
      _favorites = _favoriteFoods.map((food) => food.id).toSet();
    } catch (_) {
      if (_userId != userId || _loadGeneration != generation) return;
      _error = 'Unable to load your meals.';
    }
    if (_userId != userId || _loadGeneration != generation) return;
    _loading = false;
    notifyListeners();
    await loadReport(userId: userId, generation: generation);
  }

  Future<void> selectReportRange(ReportRange range) async {
    if (_reportRange == range && _report.isNotEmpty) return;
    _reportRange = range;
    await loadReport();
  }

  Future<void> loadReport({String? userId, int? generation}) async {
    final expectedUserId = userId ?? _userId;
    final expectedGeneration = generation ?? _loadGeneration;
    if (expectedUserId == null) return;
    _reportLoading = true;
    _reportError = null;
    notifyListeners();
    try {
      final report = await _meals.loadNutritionSummary(
        timezone: _timezone,
        days: _reportRange.days,
      );
      if (_userId != expectedUserId || _loadGeneration != expectedGeneration) {
        return;
      }
      _report = report;
    } catch (_) {
      if (_userId != expectedUserId || _loadGeneration != expectedGeneration) {
        return;
      }
      _reportError =
          'Unable to load this report. Check your connection and retry.';
    } finally {
      if (_userId == expectedUserId && _loadGeneration == expectedGeneration) {
        _reportLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> toggleFavorite(Food food) async {
    final userId = _currentUserId();
    final generation = _loadGeneration;
    if (userId == null || _userId != userId) return false;
    final previousFavorites = _favorites;
    final previousFoods = _favoriteFoods;
    final exists = isFavorite(food);
    if (exists) {
      _favorites = {..._favorites}..remove(food.id);
      _favoriteFoods = _favoriteFoods
          .where((item) => item.id != food.id)
          .toList();
    } else {
      _favorites = {..._favorites, food.id};
      _favoriteFoods = [food, ..._favoriteFoods];
    }
    notifyListeners();
    try {
      if (exists) {
        await _client.from('user_favorites').delete().eq('food_id', food.id);
      } else {
        await _client.from('user_favorites').insert({
          'user_id': userId,
          'food_id': food.id,
        });
      }
      return _isCurrentAccount(userId, generation);
    } catch (_) {
      if (!_isCurrentAccount(userId, generation)) return false;
      _favorites = previousFavorites;
      _favoriteFoods = previousFoods;
      notifyListeners();
      return false;
    }
  }

  Future<bool> add(Food food, MealType type, double servings) async {
    final userId = _userId;
    final generation = _loadGeneration;
    if (servings <= 0 || userId == null || _currentUserId() != userId) {
      return false;
    }
    try {
      await _meals.add(food, type, servings);
      if (!_isCurrentAccount(userId, generation)) return false;
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateServings(String id, double servings) async {
    final userId = _userId;
    final generation = _loadGeneration;
    if (servings <= 0 || userId == null || _currentUserId() != userId) {
      return false;
    }
    try {
      await _meals.updateServings(id, servings);
      if (!_isCurrentAccount(userId, generation)) return false;
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> remove(String id) async {
    final userId = _userId;
    final generation = _loadGeneration;
    if (userId == null || _currentUserId() != userId) return false;
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) return false;
    final removed = _entries[index];
    _entries = [..._entries]..removeAt(index);
    notifyListeners();
    try {
      await _meals.remove(id, userId: userId);
      if (!_isCurrentAccount(userId, generation)) return false;
      await load();
      return true;
    } catch (_) {
      if (!_isCurrentAccount(userId, generation)) return false;
      _entries = [..._entries]..insert(index, removed);
      notifyListeners();
      return false;
    }
  }
}
