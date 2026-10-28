import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/models/food.dart';
import 'package:foodtrack/models/recipe_nutrition.dart';

void main() {
  const rice = Food(
    id: 'rice',
    name: 'Rice',
    category: 'Grains',
    emoji: '🍚',
    servingLabel: '1 cup',
    calories: 200,
    protein: 4,
    carbs: 44,
    fat: 1,
    fiber: 1,
    sugar: 0,
    sodium: 10,
  );
  const chicken = Food(
    id: 'chicken',
    name: 'Chicken',
    category: 'Protein',
    emoji: '🍗',
    servingLabel: '100 g',
    calories: 150,
    protein: 30,
    carbs: 0,
    fat: 4,
    fiber: 0,
    sugar: 0,
    sodium: 70,
  );

  test('calculates nutrition per recipe serving from ingredient servings', () {
    final nutrition = RecipeNutrition.fromIngredients(const [
      RecipeIngredient(food: rice, servings: 2),
      RecipeIngredient(food: chicken, servings: 1),
    ], recipeServings: 2);

    expect(nutrition.calories, 275);
    expect(nutrition.protein, 19);
    expect(nutrition.carbs, 44);
    expect(nutrition.fat, 3);
    expect(nutrition.fiber, 1);
    expect(nutrition.sugar, 0);
    expect(nutrition.sodium, 45);
  });

  test('rejects invalid ingredient amounts and recipe yield', () {
    expect(
      () => RecipeNutrition.fromIngredients(const [
        RecipeIngredient(food: rice, servings: 0),
      ], recipeServings: 1),
      throwsArgumentError,
    );
    expect(
      () => RecipeNutrition.fromIngredients(const [
        RecipeIngredient(food: rice, servings: 1),
      ], recipeServings: 0),
      throwsArgumentError,
    );
  });
}
