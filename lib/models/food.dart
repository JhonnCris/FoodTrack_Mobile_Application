class Food {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final String servingLabel; // e.g. "1 cup (100 g)"
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium; // mg
  final List<String> allergens;
  final List<String> dietTags; // vegan, vegetarian, pescatarian
  final String description;
  final bool isVerified;
  final String? nutritionSourceName;
  final String? nutritionSourceUrl;
  final String? allergenSourceName;
  final String? allergenSourceUrl;
  final DateTime? reviewedAt;
  final Set<String> unavailableNutrients;

  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.servingLabel,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.allergens = const [],
    this.dietTags = const [],
    this.description = '',
    this.isVerified = false,
    this.nutritionSourceName,
    this.nutritionSourceUrl,
    this.allergenSourceName,
    this.allergenSourceUrl,
    this.reviewedAt,
    this.unavailableNutrients = const {},
  });

  bool isNutrientAvailable(String nutrient) =>
      !unavailableNutrients.contains(nutrient);

  bool get hasIncompleteNutrition => unavailableNutrients.isNotEmpty;

  String formattedNutrient(
    String nutrient, {
    required int decimalPlaces,
    required String unit,
  }) {
    if (!isNutrientAvailable(nutrient)) return 'Not available';
    final value = switch (nutrient) {
      'calories' => calories,
      'protein' => protein,
      'carbs' => carbs,
      'fat' => fat,
      'fiber' => fiber,
      'sugar' => sugar,
      'sodium' => sodium,
      _ => throw ArgumentError.value(nutrient, 'nutrient'),
    };
    return '${value.toStringAsFixed(decimalPlaces)} $unit';
  }

  /// Simple, rule-based indicators. Not "good/bad" — just what stands out.
  List<FoodIndicator> get indicators {
    final list = <FoodIndicator>[];
    if (isNutrientAvailable('protein') && protein >= 12) {
      list.add(FoodIndicator('High protein', true));
    }
    if (isNutrientAvailable('fiber') && fiber >= 4) {
      list.add(FoodIndicator('Good fiber', true));
    }
    if (isNutrientAvailable('sugar') && sugar >= 10) {
      list.add(FoodIndicator('High sugar', false));
    }
    if (isNutrientAvailable('sodium') && sodium >= 400) {
      list.add(FoodIndicator('High sodium', false));
    }
    if (isNutrientAvailable('fat') && fat >= 15) {
      list.add(FoodIndicator('High fat', false));
    }
    return list;
  }
}

class FoodIndicator {
  final String label;
  final bool positive;
  final String explanation;

  FoodIndicator(this.label, this.positive)
    : explanation = switch (label) {
        'High protein' => 'This serving provides at least 12 g of protein, which contributes to your daily protein target.',
        'Good fiber' => 'This serving provides at least 4 g of fiber, which contributes to your daily fiber intake.',
        'High sugar' => 'This serving contains at least 10 g of sugar. Compare serving sizes and choose what fits your needs.',
        'High sodium' => 'This serving contains at least 400 mg of sodium. Consider your overall sodium intake for the day.',
        'High fat' => 'This serving contains at least 15 g of fat. Fat is an essential nutrient; this indicator describes the amount, not whether the food is good or bad.',
        _ => 'A nutrition value that stands out for this serving.',
      };
}
