class DailyNutrition {
  const DailyNutrition({
    required this.day,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final DateTime day;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  factory DailyNutrition.fromRow(Map<String, dynamic> row) => DailyNutrition(
    day: DateTime.parse(row['day'] as String),
    calories: (row['calories_kcal'] as num?)?.toDouble() ?? 0,
    protein: (row['protein_g'] as num?)?.toDouble() ?? 0,
    carbs: (row['carbs_g'] as num?)?.toDouble() ?? 0,
    fat: (row['fat_g'] as num?)?.toDouble() ?? 0,
  );
}
