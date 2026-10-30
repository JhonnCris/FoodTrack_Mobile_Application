import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/food_repository.dart';
import '../models/food.dart';
import '../models/user_profile.dart';
import 'diary_viewmodel.dart';

class Recommendation {
  final Food food;
  final double score;
  final String reason;

  Recommendation(this.food, this.score, this.reason);
}

class RecommendationViewModel extends ChangeNotifier {
  RecommendationViewModel(this._repo, this._client);

  final FoodRepository _repo;
  final SupabaseClient _client;
  List<Recommendation> _items = [];
  String? _lastSignature;
  String? _pendingSignature;
  List<Food>? _cachedFoods;
  Timer? _generationTimer;
  String? _userId;
  int _sessionGeneration = 0;

  List<Recommendation> get items => _items;

  /// Makes a newly created food available without requiring an app restart.
  void addCustomFood(Food food) {
    if (_cachedFoods != null &&
        !_cachedFoods!.any((item) => item.id == food.id)) {
      _cachedFoods = [..._cachedFoods!, food];
    }
    _lastSignature = null;
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sessionGeneration++;
    _generationTimer?.cancel();
    _items = [];
    _cachedFoods = null;
    _lastSignature = null;
    _pendingSignature = null;
    notifyListeners();
  }

  Future<void> generate(
    UserProfile profile,
    DiaryViewModel diary, {
    String trigger = 'profile_change',
  }) async {
    final userId = _userId;
    if (userId == null) return;

    final allergies = profile.allergies.toList()..sort();
    final dislikes = profile.dislikedFoods.toList()..sort();
    final signature =
        '${profile.goal.code}:${profile.diet.name}:${allergies.join(',')}:'
        '${dislikes.join(',')}:${diary.totalCalories.round()}:'
        '${diary.totalProtein.round()}';
    if ((signature == _lastSignature || signature == _pendingSignature) &&
        trigger != 'manual') {
      return;
    }
    if (trigger != 'manual') {
      _generationTimer?.cancel();
      _pendingSignature = signature;
      final generation = _sessionGeneration;
      _generationTimer = Timer(const Duration(milliseconds: 350), () {
        if (_pendingSignature == signature &&
            _sessionGeneration == generation) {
          unawaited(_generateNow(profile, diary, trigger, signature));
        }
      });
      return;
    }
    await _generateNow(profile, diary, trigger, signature);
  }

  Future<void> _generateNow(
    UserProfile profile,
    DiaryViewModel diary,
    String trigger,
    String signature,
  ) async {
    final userId = _userId;
    final generation = _sessionGeneration;
    if (userId == null) return;

    try {
      final foods = _cachedFoods ?? await _repo.loadAllFoods();
      if (_userId != userId || _sessionGeneration != generation) return;
      _cachedFoods = foods;

      final recommendations = <Recommendation>[];
      final remaining = (profile.calorieTarget - diary.totalCalories).clamp(
        0.0,
        double.infinity,
      );
      for (final food in foods) {
        final text = '${food.name} ${food.description}'.toLowerCase();
        if (food.allergens.any(profile.allergies.contains) ||
            profile.allergies.any(
              (allergy) => text.contains(allergy.toLowerCase()),
            ) ||
            profile.dislikedFoods.any(
              (dislike) =>
                  food.name.toLowerCase().contains(dislike.toLowerCase()),
            )) {
          continue;
        }
        if (profile.diet != DietPreference.none &&
            !food.dietTags.contains(profile.diet.name) &&
            !(profile.diet == DietPreference.vegetarian &&
                food.dietTags.contains('vegan'))) {
          continue;
        }
        var score = _score(food, profile.goal);
        if (food.calories > remaining && remaining > 0) score *= .65;
        if (score > 0) {
          recommendations.add(
            Recommendation(food, score, _reason(food, profile.goal, remaining)),
          );
        }
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));
      if (_userId != userId || _sessionGeneration != generation) return;
      _items = recommendations.take(5).toList();
      _lastSignature = signature;
      notifyListeners();

      if (_client.auth.currentUser?.id == userId &&
          _sessionGeneration == generation) {
        await _client.rpc(
          'record_recommendation_event',
          params: {
            'p_trigger_type': trigger,
            'p_recommendations': _items
                .map((recommendation) => {'food_id': recommendation.food.id})
                .toList(),
          },
        );
      }
    } finally {
      if (_pendingSignature == signature) _pendingSignature = null;
    }
  }

  double _score(Food food, FitnessGoal goal) => switch (goal) {
    FitnessGoal.muscle =>
      food.calories == 0 ? 0 : food.protein * 400 / food.calories,
    FitnessGoal.weightLoss =>
      200 / (food.calories / (food.protein + food.fiber + 1) + 1),
    FitnessGoal.weightGain => food.calories / 3,
    FitnessGoal.fiber => food.fiber * 10,
    FitnessGoal.balanced =>
      ((food.protein > 3 ? 1 : 0) +
              (food.fiber > 2 ? 1 : 0) +
              (food.fat < 10 ? 1 : 0) +
              (food.sodium < 300 ? 1 : 0)) *
          25.0,
  };

  String _reason(Food food, FitnessGoal goal, double remaining) =>
      '${goal.label}: ${food.protein.toStringAsFixed(0)} g protein, '
      '${food.fiber.toStringAsFixed(1)} g fiber; '
      '${remaining.toStringAsFixed(0)} kcal remaining today.';

  @override
  void dispose() {
    _generationTimer?.cancel();
    super.dispose();
  }
}
