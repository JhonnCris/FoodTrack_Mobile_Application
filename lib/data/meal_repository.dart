import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';
import '../models/daily_nutrition.dart';
import '../models/meal_entry.dart';

class MealRepository {
  MealRepository(this._client);
  final SupabaseClient _client;

  Future<List<MealEntry>> loadToday(String timezone) async {
    final bounds = await _client.rpc('current_day_bounds', params: {'p_timezone': timezone}).single();
    final start = bounds['start_at'] as String;
    final end = bounds['end_at'] as String;
    final rows = await _client.from('meal_entries').select(
        '*, foods(*, food_categories(display_name), food_allergens(allergens(code)), food_diet_tags(diet_tag_code)), meal_entry_nutrition(*)')
      .gte('logged_at', start).lt('logged_at', end)
      .order('logged_at');
    return (rows as List).map((row) => _entry(Map<String, dynamic>.from(row))).toList();
  }

  Future<List<DailyNutrition>> loadNutritionSummary({
    required String timezone,
    required int days,
  }) async {
    final rows = await _client.rpc('nutrition_summary', params: {
      'p_timezone': timezone,
      'p_days': days,
    });
    return (rows as List).map((row) => DailyNutrition.fromRow(Map<String, dynamic>.from(row))).toList();
  }

  Future<void> add(Food food, MealType type, double servings) => _client.rpc('create_meal_entry', params: {
    'p_food_id': food.id, 'p_meal_type_code': type.name, 'p_servings': servings,
    'p_logged_at': DateTime.now().toUtc().toIso8601String(),
  });
  Future<void> updateServings(String id, double servings) => _client.rpc('update_meal_entry_servings', params: {'p_entry_id': id, 'p_servings': servings});
  Future<void> remove(String id) => _client.from('meal_entries').delete().eq('id', id);

  MealEntry _entry(Map<String, dynamic> row) {
    final f = Map<String, dynamic>.from(row['foods'] as Map);
    final n = ((row['meal_entry_nutrition'] as List?)?.firstOrNull as Map?) ?? const {};
    double d(Map value, String key) => (value[key] as num?)?.toDouble() ?? 0;
    final allergens = (f['food_allergens'] as List? ?? const []).map((e) => ((e as Map)['allergens'] as Map?)?['code'] as String?).whereType<String>().toList();
    final tags = (f['food_diet_tags'] as List? ?? const []).map((e) => (e as Map)['diet_tag_code'] as String?).whereType<String>().toList();
    final food = Food(id: f['id'], name: f['name'], category: ((f['food_categories'] as Map?)?['display_name'] as String?) ?? 'Custom', emoji: f['emoji'] ?? '🍽️', servingLabel: f['serving_label'], calories: d(f,'calories_kcal'), protein: d(f,'protein_g'), carbs: d(f,'carbs_g'), fat: d(f,'fat_g'), fiber: d(f,'fiber_g'), sugar: d(f,'sugar_g'), sodium: d(f,'sodium_mg'), allergens: allergens, dietTags: tags, description: f['description'] ?? '');
    return MealEntry(id: row['id'], food: food, type: MealType.values.byName(row['meal_type_code']), servings: d(row,'servings'), date: DateTime.parse(row['logged_at']), snapshotCalories: d(n,'calories_kcal'), snapshotProtein: d(n,'protein_g'), snapshotCarbs: d(n,'carbs_g'), snapshotFat: d(n,'fat_g'));
  }
}
