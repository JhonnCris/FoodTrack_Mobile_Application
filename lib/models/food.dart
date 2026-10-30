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
  });

  /// Simple, rule-based indicators. Not "good/bad" — just what stands out.
  List<FoodIndicator> get indicators {
    final list = <FoodIndicator>[];
    if (protein >= 12) list.add(FoodIndicator('High protein', true));
    if (fiber >= 4) list.add(FoodIndicator('Good fiber', true));
    if (sugar >= 10) list.add(FoodIndicator('High sugar', false));
    if (sodium >= 400) list.add(FoodIndicator('High sodium', false));
    if (fat >= 15) list.add(FoodIndicator('High fat', false));
    return list;
  }
}

class FoodIndicator {
  final String label;
  final bool positive;
  FoodIndicator(this.label, this.positive);
}
