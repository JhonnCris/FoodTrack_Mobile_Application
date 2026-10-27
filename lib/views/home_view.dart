import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/meal_entry.dart';
import '../viewmodels/diary_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/recommendation_viewmodel.dart';
import 'reports_view.dart';
import 'widgets/common_widgets.dart';

class HomeView extends StatelessWidget {
  /// Lets the Home tab jump to other tabs (Log / For You).
  final void Function(int index) onGoToTab;
  const HomeView({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryViewModel>();
    final profile = context.watch<ProfileViewModel>().profile;
    final recs = context.watch<RecommendationViewModel>().items;

    final remaining = profile.calorieTarget - diary.totalCalories;
    final pct = (diary.totalCalories / profile.calorieTarget).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text('Hi, ${profile.name} 👋')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Calorie ring card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: pct,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: AppColors.green,
                          backgroundColor: AppColors.greenLight,
                        ),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(diary.totalCalories.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800)),
                        const Text('kcal eaten',
                            style: TextStyle(fontSize: 11)),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _stat('Target', profile.calorieTarget.toStringAsFixed(0)),
                        const SizedBox(height: 10),
                        _stat(
                          remaining >= 0 ? 'Remaining' : 'Over by',
                          remaining.abs().toStringAsFixed(0),
                        ),
                        if (profile.targetsAreEstimated) ...[
                          const SizedBox(height: 10),
                          Text('Estimated target',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: MacroBar(
                          label: 'Protein',
                          value: diary.totalProtein,
                          target: profile.proteinTarget,
                          color: AppColors.protein)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: MacroBar(
                          label: 'Carbs',
                          value: diary.totalCarbs,
                          target: profile.carbsTarget,
                          color: AppColors.carbs)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: MacroBar(
                          label: 'Fat',
                          value: diary.totalFat,
                          target: profile.fatTarget,
                          color: AppColors.fat)),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => onGoToTab(2),
            icon: const Icon(Icons.add),
            label: const Text('Log food'),
          ),
          const SizedBox(height: 20),

          // Meals summary
          const SectionHeader('Today\'s meals'),
          ...MealType.values.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 40,
                      height: 40,
                      child: MealCategoryImage(category: t.name),
                    ),
                    title: Text(t.label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${diary.entriesFor(t).length} items'),
                    trailing: Text(
                        '${diary.caloriesFor(t).toStringAsFixed(0)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () => onGoToTab(2),
                  ),
                ),
              )),
          const SizedBox(height: 12),

          // Recommendation preview
          SectionHeader('For you', action: 'See all', onAction: () => onGoToTab(3)),
          if (recs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Complete your profile to get recommendations.'),
              ),
            )
          else
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recs.length.clamp(0, 5),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = recs[i];
                  return SizedBox(
                    width: 150,
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onGoToTab(3),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FoodImage(food: r.food, compact: true),
                              const Spacer(),
                              Text(r.food.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${r.food.calories.toStringAsFixed(0)} kcal',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // Weekly report shortcut
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart_rounded,
                  color: AppColors.green),
              title: const Text('Weekly report',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('See your calorie trend'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsView())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      );
}
