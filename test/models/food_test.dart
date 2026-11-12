import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/models/food.dart';

void main() {
  test('food model carries optional provenance and defaults to unverified', () {
    const unverified = Food(
      id: 'custom',
      name: 'Custom food',
      category: 'Custom',
      emoji: '🍽️',
      servingLabel: '1 serving',
      calories: 100,
      protein: 10,
      carbs: 10,
      fat: 5,
    );
    const reviewed = Food(
      id: 'reviewed',
      name: 'Reviewed food',
      category: 'Test',
      emoji: '🥗',
      servingLabel: '1 serving',
      calories: 100,
      protein: 12,
      carbs: 10,
      fat: 5,
      isVerified: true,
      nutritionSourceName: 'Nutrition reference',
      nutritionSourceUrl: 'https://example.com/nutrition',
      allergenSourceName: 'Allergen reference',
      allergenSourceUrl: 'https://example.com/allergens',
    );

    expect(unverified.isVerified, isFalse);
    expect(unverified.nutritionSourceName, isNull);
    expect(reviewed.isVerified, isTrue);
    expect(reviewed.nutritionSourceUrl, 'https://example.com/nutrition');
    expect(reviewed.allergenSourceUrl, 'https://example.com/allergens');
    expect(reviewed.indicators, isNotEmpty);
    expect(reviewed.indicators.first.explanation, contains('serving'));
  });

  test(
    'nutrition indicators identify high protein, fiber, sugar, sodium, and fat',
    () {
      const food = Food(
        id: 'food',
        name: 'Test food',
        category: 'Test',
        emoji: '🥗',
        servingLabel: '1 serving',
        calories: 100,
        protein: 12,
        carbs: 10,
        fat: 15,
        fiber: 4,
        sugar: 10,
        sodium: 400,
      );

      expect(food.indicators.map((indicator) => indicator.label), [
        'High protein',
        'Good fiber',
        'High sugar',
        'High sodium',
        'High fat',
      ]);
    },
  );

  test('missing nutrient metadata is distinguishable from a measured zero', () {
    const food = Food(
      id: 'incomplete',
      name: 'Incomplete food',
      category: 'Test',
      emoji: '🍽️',
      servingLabel: '1 serving',
      calories: 100,
      protein: 0,
      carbs: 10,
      fat: 5,
      unavailableNutrients: {'protein'},
    );

    expect(food.protein, 0);
    expect(food.isNutrientAvailable('protein'), isFalse);
    expect(
      food.formattedNutrient('protein', decimalPlaces: 0, unit: 'g'),
      'Not available',
    );
    expect(food.isNutrientAvailable('carbs'), isTrue);
    expect(food.hasIncompleteNutrition, isTrue);
  });
}
