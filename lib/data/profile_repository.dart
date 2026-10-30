import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);
  final SupabaseClient _client;
  Future<UserProfile?> load({String? userId}) async {
    final id = userId ?? _client.auth.currentUser?.id;
    if (id == null) return null;
    final row = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', id)
        .maybeSingle();
    if (row == null) return null;
    final allergies = await _client
        .from('user_allergies')
        .select('custom_name, allergens(code)')
        .eq('user_id', id);
    final dislikes = await _client
        .from('user_disliked_foods')
        .select('custom_name')
        .eq('user_id', id);
    return UserProfile(
      name: row['display_name'] ?? 'Guest',
      birthDate:
          DateTime.tryParse(row['birth_date'] ?? '') ??
          DateTime(DateTime.now().year - 21),
      heightCm: (row['height_cm'] as num?)?.toDouble() ?? 168,
      weightKg: (row['current_weight_kg'] as num?)?.toDouble() ?? 62,
      sex: ProfileSexX.fromCode(row['sex']),
      goal: FitnessGoalX.fromCode(row['goal_code']),
      activity:
          ActivityLevel.values
              .where((v) => v.name == row['activity_level_code'])
              .firstOrNull ??
          ActivityLevel.light,
      diet:
          DietPreference.values
              .where((v) => v.name == row['diet_preference_code'])
              .firstOrNull ??
          DietPreference.none,
      timezone: row['timezone'] ?? 'Asia/Manila',
      allergies: (allergies as List)
          .map((r) => r['custom_name'] ?? ((r['allergens'] as Map?)?['code']))
          .whereType<String>()
          .toSet(),
      dislikedFoods: (dislikes as List)
          .map((r) => r['custom_name'])
          .whereType<String>()
          .toSet(),
      calorieTarget: (row['calorie_target'] as num?)?.toDouble() ?? 2000,
      proteinTarget: (row['protein_target_g'] as num?)?.toDouble() ?? 100,
      carbsTarget: (row['carbs_target_g'] as num?)?.toDouble() ?? 250,
      fatTarget: (row['fat_target_g'] as num?)?.toDouble() ?? 65,
      targetsAreEstimated: row['targets_are_estimated'] ?? true,
      onboardingCompletedAt: DateTime.tryParse(
        row['onboarding_completed_at'] ?? '',
      ),
    );
  }

  Future<void> save(UserProfile p, {required bool onboarded}) async {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('You must be signed in to save a profile.');
    }
    final known = p.allergies
        .where(UserProfile.canonicalAllergenCodes.contains)
        .toList();
    final custom = p.allergies
        .where((a) => !UserProfile.canonicalAllergenCodes.contains(a))
        .toList();
    await _client.rpc(
      'save_user_profile',
      params: {
        'p_profile': {
          'display_name': p.name,
          'birth_date': p.birthDate.toIso8601String().substring(0, 10),
          'height_cm': p.heightCm,
          'current_weight_kg': p.weightKg,
          'sex': p.sex.code,
          'goal_code': p.goal.code,
          'activity_level_code': p.activity.name,
          'diet_preference_code': p.diet.name,
          'timezone': p.timezone,
          'calorie_target': p.calorieTarget,
          'protein_target_g': p.proteinTarget,
          'carbs_target_g': p.carbsTarget,
          'fat_target_g': p.fatTarget,
          'targets_are_estimated': p.targetsAreEstimated,
          'onboarding_completed_at':
              onboarded && p.onboardingCompletedAt != null
              ? p.onboardingCompletedAt!.toUtc().toIso8601String()
              : '',
        },
        'p_known_allergen_codes': known,
        'p_custom_allergen_names': custom,
        'p_disliked_food_names': p.dislikedFoods.toList(),
      },
    );
  }
}
