import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/account_export.dart';

void main() {
  test('serializes every export section and account metadata', () {
    final json = jsonDecode(
      encodeAccountExport(
        userId: 'account-a',
        email: 'account-a@example.test',
        createdAt: '2026-01-01T00:00:00Z',
        profile: {'display_name': 'Account A'},
        allergies: [
          {'code': 'peanut'},
        ],
        dislikes: [
          {'custom_name': 'example'},
        ],
        favorites: [
          {'food_id': 'favorite-food'},
        ],
        customFoods: [
          {'id': 'custom-food'},
        ],
        meals: [
          {'id': 'meal-entry'},
        ],
        recommendations: [
          {
            'recommendations': ['recommended-food'],
          },
        ],
        pendingProfileWrite: {'userId': 'account-a'},
        exportedAt: DateTime.utc(2026, 1, 2),
      ),
    ) as Map<String, dynamic>;

    expect(json.keys.toSet(), {
      'format',
      'version',
      'exported_at',
      'account',
      'user_profile',
      'allergies',
      'disliked_foods',
      'favorites',
      'custom_foods',
      'meal_entries',
      'recommendation_events',
      'pending_profile_write',
    });
    expect(json['format'], 'foodtrack-account-export');
    expect(json['version'], 1);
    expect(json['exported_at'], '2026-01-02T00:00:00.000Z');
    expect(json['account'], {
      'id': 'account-a',
      'email': 'account-a@example.test',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(json['user_profile'], {'display_name': 'Account A'});
    expect(json['allergies'], [
      {'code': 'peanut'},
    ]);
    expect(json['disliked_foods'], [
      {'custom_name': 'example'},
    ]);
    expect(json['favorites'], [
      {'food_id': 'favorite-food'},
    ]);
    expect(json['custom_foods'], [
      {'id': 'custom-food'},
    ]);
    expect(json['meal_entries'], [
      {'id': 'meal-entry'},
    ]);
    expect(json['recommendation_events'], [
      {
        'recommendations': ['recommended-food'],
      },
    ]);
    expect(json['pending_profile_write'], {'userId': 'account-a'});
  });
}
