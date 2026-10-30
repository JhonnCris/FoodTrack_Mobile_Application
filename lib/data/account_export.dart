import 'dart:convert';

String encodeAccountExport({
  required String userId,
  required String? email,
  required String createdAt,
  required Map<String, dynamic>? profile,
  required List<Map<String, dynamic>> allergies,
  required List<Map<String, dynamic>> dislikes,
  required List<Map<String, dynamic>> favorites,
  required List<Map<String, dynamic>> customFoods,
  required List<Map<String, dynamic>> meals,
  required List<Map<String, dynamic>> recommendations,
  required Map<String, dynamic>? pendingProfileWrite,
  DateTime? exportedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': 'foodtrack-account-export',
    'version': 1,
    'exported_at': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'account': {'id': userId, 'email': email, 'created_at': createdAt},
    'user_profile': profile,
    'allergies': allergies,
    'disliked_foods': dislikes,
    'favorites': favorites,
    'custom_foods': customFoods,
    'meal_entries': meals,
    'recommendation_events': recommendations,
    'pending_profile_write': pendingProfileWrite,
  });
}
