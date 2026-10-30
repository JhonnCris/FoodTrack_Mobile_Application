import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food.dart';
import '../models/meal_entry.dart';
import '../viewmodels/diary_viewmodel.dart';
import '../viewmodels/food_viewmodel.dart';
import 'widgets/common_widgets.dart';

class LogView extends StatelessWidget {
  const LogView({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s log')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          for (final type in MealType.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SectionHeader(
                type.label,
                action: '+ Add',
                onAction: () => _openPicker(context, type),
              ),
            ),
            if (diary.entriesFor(type).isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nothing logged yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ...diary
                  .entriesFor(type)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EntryTile(entry: e),
                    ),
                  ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPicker(context, MealType.snack),
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
    );
  }

  void _openPicker(BuildContext context, MealType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FoodPickerSheet(type: type),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final MealEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final diary = context.read<DiaryViewModel>();
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final removed = await diary.remove(entry.id);
        if (!context.mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed
                  ? '${entry.food.name} removed'
                  : 'Could not remove ${entry.food.name}. Please try again.',
            ),
          ),
        );
        return removed;
      },
      child: FoodTile(
        food: entry.food,
        subtitleOverride:
            '${entry.servings.toStringAsFixed(entry.servings == entry.servings.roundToDouble() ? 0 : 1)} serving${entry.servings == 1 ? '' : 's'} (${entry.food.servingLabel}) · ${entry.calories.toStringAsFixed(0)} kcal',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Less',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _changeServings(context, entry.servings - 0.5),
            ),
            IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _changeServings(context, entry.servings + 0.5),
            ),
          ],
        ),
        onTap: () {},
      ),
    );
  }

  Future<void> _changeServings(BuildContext context, double servings) async {
    final updated = await context.read<DiaryViewModel>().updateServings(
      entry.id,
      servings,
    );
    if (!context.mounted || updated) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not update servings. Check your connection and try again.',
        ),
      ),
    );
  }
}

class _FoodPickerSheet extends StatelessWidget {
  final MealType type;
  const _FoodPickerSheet({required this.type});

  @override
  Widget build(BuildContext context) {
    final foodVm = context.watch<FoodViewModel>();
    final diary = context.watch<DiaryViewModel>();
    final showShortcuts = foodVm.query.isEmpty && foodVm.category == 'All';

    Widget list(String title, List<Food> foods) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ...foods.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FoodTile(
              food: f,
              trailing: const Icon(Icons.add_circle, color: Colors.green),
              onTap: () {
                Navigator.pop(context);
                showAddToLogSheet(context, f, initial: type);
              },
            ),
          ),
        ),
      ],
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add to ${type.label}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: foodVm.setQuery,
              decoration: const InputDecoration(
                hintText: 'Search foods',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  if (showShortcuts && diary.favoriteFoods.isNotEmpty)
                    list('Favorites', diary.favoriteFoods),
                  if (showShortcuts && diary.recentFoods.isNotEmpty)
                    list('Recent', diary.recentFoods.take(5).toList()),
                  list(showShortcuts ? 'All foods' : 'Results', foodVm.results),
                  if (foodVm.error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextButton(
                        onPressed: foodVm.results.isEmpty
                            ? foodVm.load
                            : foodVm.loadMore,
                        child: Text(foodVm.error!),
                      ),
                    )
                  else if (foodVm.hasMore || foodVm.loadingMore)
                    Center(
                      child: TextButton(
                        onPressed: foodVm.loadingMore ? null : foodVm.loadMore,
                        child: foodVm.loadingMore
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Load more foods'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
