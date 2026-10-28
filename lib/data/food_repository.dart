import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';

class FoodRepository {
  FoodRepository(this._client);
  final SupabaseClient _client;

  Future<List<Food>> loadFoods() async {
    final rows = await _client
        .from('foods')
        .select(
          '*, food_categories(display_name), food_allergens(allergens(code)), food_diet_tags(diet_tag_code)',
        )
        .order('name');
    return (rows as List)
        .map((row) => _food(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<Food>> loadFavorites() async {
    final rows = await _client
        .from('user_favorites')
        .select(
          'foods(*, food_categories(display_name), food_allergens(allergens(code)), food_diet_tags(diet_tag_code))',
        )
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => _food(Map<String, dynamic>.from(row['foods'] as Map)))
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
    final requestedCategory = category.trim();
    final categoryRow = requestedCategory.isEmpty
        ? null
        : await _client
              .from('food_categories')
              .select('id')
              .ilike('display_name', requestedCategory)
              .maybeSingle();
    final fallbackCategory = await _client
        .from('food_categories')
        .select('id')
        .eq('code', 'custom')
        .single();
    final row = await _client
        .from('foods')
        .insert({
          'name': name,
          'serving_label': servingLabel.isEmpty ? '1 serving' : servingLabel,
          'calories_kcal': calories,
          'protein_g': protein,
          'carbs_g': carbs,
          'fat_g': fat,
          'fiber_g': fiber,
          'sugar_g': sugar,
          'sodium_mg': sodium,
          'description': description,
          'category_id': categoryRow?['id'] ?? fallbackCategory['id'],
          'created_by_user_id': _client.auth.currentUser!.id,
          'visibility': 'private',
          'emoji': '🍽️',
        })
        .select(
          '*, food_categories(display_name), food_allergens(allergens(code)), food_diet_tags(diet_tag_code)',
        )
        .single();
    return _food(Map<String, dynamic>.from(row));
  }

  Food _food(Map<String, dynamic> row) {
    double number(String key) => (row[key] as num?)?.toDouble() ?? 0;
    final category = row['food_categories'] as Map<String, dynamic>?;
    final allergenRows = row['food_allergens'] as List? ?? const [];
    final tagRows = row['food_diet_tags'] as List? ?? const [];
    return Food(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category?['display_name'] as String? ?? 'Custom',
      emoji: row['emoji'] as String? ?? '🍽️',
      servingLabel: row['serving_label'] as String,
      calories: number('calories_kcal'),
      protein: number('protein_g'),
      carbs: number('carbs_g'),
      fat: number('fat_g'),
      fiber: number('fiber_g'),
      sugar: number('sugar_g'),
      sodium: number('sodium_mg'),
      description: row['description'] as String? ?? '',
      allergens: allergenRows
          .map(
            (item) => ((item as Map)['allergens'] as Map?)?['code'] as String?,
          )
          .whereType<String>()
          .toList(),
      dietTags: tagRows
          .map((item) => (item as Map)['diet_tag_code'] as String?)
          .whereType<String>()
          .toList(),
    );
  }
}
