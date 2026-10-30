import 'food.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snacks',
  };

  String get emoji => switch (this) {
    MealType.breakfast => '🌅',
    MealType.lunch => '☀️',
    MealType.dinner => '🌙',
    MealType.snack => '🍎',
  };
}

class MealEntry {
  final String id;
  final Food food;
  final MealType type;
  final double servings;
  final DateTime date;
  final double? snapshotCalories;
  final double? snapshotProtein;
  final double? snapshotCarbs;
  final double? snapshotFat;

  const MealEntry({
    required this.id,
    required this.food,
    required this.type,
    required this.servings,
    required this.date,
    this.snapshotCalories,
    this.snapshotProtein,
    this.snapshotCarbs,
    this.snapshotFat,
  });

  double get calories => snapshotCalories ?? food.calories * servings;
  double get protein => snapshotProtein ?? food.protein * servings;
  double get carbs => snapshotCarbs ?? food.carbs * servings;
  double get fat => snapshotFat ?? food.fat * servings;

  MealEntry copyWith({double? servings, MealType? type}) => MealEntry(
    id: id,
    food: food,
    type: type ?? this.type,
    servings: servings ?? this.servings,
    date: date,
    snapshotCalories: snapshotCalories,
    snapshotProtein: snapshotProtein,
    snapshotCarbs: snapshotCarbs,
    snapshotFat: snapshotFat,
  );
}
