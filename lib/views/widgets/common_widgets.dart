import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_image_assets.dart';
import '../../models/food.dart';
import '../../models/meal_entry.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/diary_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

/// Labeled progress bar for protein / carbs / fat.
class MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            color: color,
            backgroundColor: color.withAlpha(40),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// Chip with an icon AND text, so meaning never depends on color alone.
class IndicatorChip extends StatelessWidget {
  final FoodIndicator indicator;
  const IndicatorChip(this.indicator, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = indicator.positive ? AppColors.green : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            indicator.positive ? Icons.check_circle : Icons.info_outline,
            size: 13,
            color: c,
          ),
          const SizedBox(width: 4),
          Text(
            indicator.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class FoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? subtitleOverride;

  const FoodTile({
    super.key,
    required this.food,
    required this.onTap,
    this.trailing,
    this.subtitleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileViewModel>().profile;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FoodImage(food: food, compact: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleOverride ??
                          'Serving size: ${food.servingLabel} · ${food.calories.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    FoodCompatibilityWarning(food: food, profile: profile),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// A consistent placeholder until the user adds a local food image.
class FoodImageFallback extends StatelessWidget {
  final bool compact;

  const FoodImageFallback({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Text(
        'Image\nhere',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: compact ? 10 : 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Displays a supplied local food image, or the explicit placeholder.
class FoodImage extends StatelessWidget {
  final Food food;
  final bool compact;

  const FoodImage({super.key, required this.food, this.compact = false});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(compact ? 12 : 16),
    child: Image.asset(
      AppImageAssets.foodPath(food.name),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => FoodImageFallback(compact: compact),
    ),
  );
}

/// Displays a supplied meal-category image, or the same explicit placeholder.
class MealCategoryImage extends StatelessWidget {
  final String category;
  final bool compact;

  const MealCategoryImage({
    super.key,
    required this.category,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(compact ? 12 : 16),
    child: Image.asset(
      AppImageAssets.mealCategoryPaths[category]!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => FoodImageFallback(compact: compact),
    ),
  );
}

/// Identifies foods that conflict with the user's saved diet or allergies.
class FoodCompatibilityWarning extends StatelessWidget {
  final Food food;
  final UserProfile profile;

  const FoodCompatibilityWarning({
    super.key,
    required this.food,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final allergyMatches = food.allergens
        .where((allergen) => profile.allergies.contains(allergen))
        .toList();
    final foodText = '${food.name} ${food.description}'.toLowerCase();
    final specifiedMatches = profile.allergies
        .where(
          (allergy) =>
              !allergyMatches.contains(allergy) &&
              foodText.contains(allergy.toLowerCase()),
        )
        .toList();
    final dietConflict =
        profile.diet != DietPreference.none &&
        !food.dietTags.contains(profile.diet.name);
    if (allergyMatches.isEmpty && specifiedMatches.isEmpty && !dietConflict) {
      return const SizedBox.shrink();
    }

    final labels = <String>[
      if (allergyMatches.isNotEmpty) 'Contains: ${allergyMatches.join(', ')}',
      if (specifiedMatches.isNotEmpty)
        'Matches allergy: ${specifiedMatches.join(', ')}',
      if (dietConflict) 'Not marked ${profile.diet.label.toLowerCase()}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: Colors.orange.shade900,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                labels.join(' · '),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet used from Food detail, For You and Log: pick meal + servings.
Future<void> showAddToLogSheet(
  BuildContext context,
  Food food, {
  MealType initial = MealType.snack,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddToLogSheet(food: food, initial: initial),
    ),
  );
}

class _AddToLogSheet extends StatefulWidget {
  final Food food;
  final MealType initial;
  const _AddToLogSheet({required this.food, required this.initial});

  @override
  State<_AddToLogSheet> createState() => _AddToLogSheetState();
}

class _AddToLogSheetState extends State<_AddToLogSheet> {
  late MealType _type = widget.initial;
  double _servings = 1;

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FoodImage(food: f, compact: true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        f.servingLabel,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: MealType.values
                  .map(
                    (t) => ChoiceChip(
                      label: Text(t.label),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _servings > 0.5
                      ? () => setState(() => _servings -= 0.5)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 120,
                  child: Column(
                    children: [
                      Text(
                        _servings.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text('servings', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _servings += 0.5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${(f.calories * _servings).toStringAsFixed(0)} kcal · '
              'P ${(f.protein * _servings).toStringAsFixed(0)} g · '
              'C ${(f.carbs * _servings).toStringAsFixed(0)} g · '
              'F ${(f.fat * _servings).toStringAsFixed(0)} g',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final added = await context.read<DiaryViewModel>().add(
                  f,
                  _type,
                  _servings,
                );
                if (!context.mounted) return;
                if (added) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${f.name} added to ${_type.label}'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not add this food. Check your connection and try again.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Add to log'),
            ),
          ],
        ),
      ),
    );
  }
}
