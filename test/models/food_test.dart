import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/models/food.dart';

void main() {
  test('nutrition indicators identify high protein, fiber, sugar, sodium, and fat', () {
    const food = Food(
      id: 'food', name: 'Test food', category: 'Test', emoji: '🥗', servingLabel: '1 serving',
      calories: 100, protein: 12, carbs: 10, fat: 15, fiber: 4, sugar: 10, sodium: 400,
    );

    expect(food.indicators.map((indicator) => indicator.label), [
      'High protein', 'Good fiber', 'High sugar', 'High sodium', 'High fat',
    ]);
  });
}
