import 'food.dart';

class RecipeIngredient {
  const RecipeIngredient({required this.food, required this.servings});

  final Food food;
  final double servings;
}

class RecipeNutrition {
  const RecipeNutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;

  factory RecipeNutrition.fromIngredients(
    Iterable<RecipeIngredient> ingredients, {
    required double recipeServings,
  }) {
    if (!recipeServings.isFinite || recipeServings <= 0) {
      throw ArgumentError.value(recipeServings, 'recipeServings');
    }

    final list = ingredients.toList();
    if (list.any(
      (ingredient) => !ingredient.servings.isFinite || ingredient.servings <= 0,
    )) {
      throw ArgumentError(
        'Ingredient servings must be positive finite values.',
      );
    }

    double total(double Function(Food food) value) => list.fold(
      0,
      (sum, ingredient) => sum + value(ingredient.food) * ingredient.servings,
    );

    return RecipeNutrition(
      calories: total((food) => food.calories) / recipeServings,
      protein: total((food) => food.protein) / recipeServings,
      carbs: total((food) => food.carbs) / recipeServings,
      fat: total((food) => food.fat) / recipeServings,
      fiber: total((food) => food.fiber) / recipeServings,
      sugar: total((food) => food.sugar) / recipeServings,
      sodium: total((food) => food.sodium) / recipeServings,
    );
  }
}
