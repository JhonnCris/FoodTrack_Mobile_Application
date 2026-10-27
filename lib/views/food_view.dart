import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food.dart';
import '../viewmodels/diary_viewmodel.dart';
import '../viewmodels/food_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/recommendation_viewmodel.dart';
import 'widgets/common_widgets.dart';

class FoodView extends StatelessWidget {
  const FoodView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FoodViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Food database')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: vm.setQuery,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search foods',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: vm.categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = vm.categories[i];
              return ChoiceChip(
                label: Text(c),
                selected: vm.category == c,
                onSelected: (_) => vm.setCategory(c),
              );
            },
          ),
        ),
        Expanded(
          child: vm.results.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = vm.results[i];
                    return FoodTile(
                      food: f,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FoodDetailView(food: f)),
                      ),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomFoodSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Custom food'),
      ),
    );
  }

  void _showCustomFoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CustomFoodSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          const Text('No foods found'),
          const SizedBox(height: 4),
          Text('Try another name or add a custom food.',
              style: TextStyle(color: Colors.grey.shade600)),
        ]),
      );
}

class FoodDetailView extends StatelessWidget {
  final Food food;
  const FoodDetailView({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryViewModel>();
    final profile = context.watch<ProfileViewModel>().profile;
    final fav = diary.isFavorite(food);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(food.name),
        actions: [
          IconButton(
            tooltip: fav ? 'Remove favorite' : 'Add favorite',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: () async {
              final updated = await diary.toggleFavorite(food);
              if (!context.mounted || updated) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not update favorites. Check your connection and try again.')),
              );
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FoodImage(food: food),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Serving size: ${food.servingLabel}',
              style: TextStyle(color: Colors.grey.shade700)),
        ),
        Center(child: FoodCompatibilityWarning(food: food, profile: profile)),
        const SizedBox(height: 16),
        if (food.indicators.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: food.indicators.map(IndicatorChip.new).toList(),
          ),
        if (food.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(food.description),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              row('Calories', '${food.calories.toStringAsFixed(0)} kcal'),
              const Divider(),
              row('Protein', '${food.protein} g'),
              row('Carbs', '${food.carbs} g'),
              row('Fat', '${food.fat} g'),
              const Divider(),
              row('Fiber', '${food.fiber} g'),
              row('Sugar', '${food.sugar} g'),
              row('Sodium', '${food.sodium.toStringAsFixed(0)} mg'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (food.allergens.isNotEmpty)
          Text('May contain: ${food.allergens.join(', ')}',
              style: TextStyle(color: Colors.orange.shade800)),
        const SizedBox(height: 4),
        Text(
          'Values are estimates and vary by brand and preparation. '
          'Allergen info may be incomplete.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => showAddToLogSheet(context, food),
          icon: const Icon(Icons.add),
          label: const Text('Add to log'),
        ),
      ]),
    );
  }
}

/// Simple form so users can add foods missing from the database (FR-20).
class _CustomFoodSheet extends StatefulWidget {
  const _CustomFoodSheet();

  @override
  State<_CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends State<_CustomFoodSheet> {
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Custom');
  final _serving = TextEditingController(text: '1 serving');
  final _cal = TextEditingController();
  final _pro = TextEditingController(text: '0');
  final _carb = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _fiber = TextEditingController(text: '0');

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _serving.dispose();
    _cal.dispose();
    _pro.dispose();
    _carb.dispose();
    _fat.dispose();
    _fiber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add custom food',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Use this when a food is missing from the database.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Food name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _serving,
                  decoration: const InputDecoration(labelText: 'Serving label'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _cal,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Calories (kcal) *'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _pro,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carb,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _fiber,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fiber (g)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                final name = _name.text.trim();
                final cal = double.tryParse(_cal.text);
                if (name.isEmpty || cal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and calories are required.')),
                  );
                  return;
                }
                Food food;
                try {
                  food = await context.read<FoodViewModel>().addCustom(
                    name: name,
                    category: _category.text.trim(),
                    servingLabel: _serving.text.trim(),
                    calories: cal,
                    protein: double.tryParse(_pro.text) ?? 0,
                    carbs: double.tryParse(_carb.text) ?? 0,
                    fat: double.tryParse(_fat.text) ?? 0,
                    fiber: double.tryParse(_fiber.text) ?? 0,
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not save this food. Check your connection and try again.')),
                    );
                  }
                  return;
                }
                if (!context.mounted) return;
                final profile = context.read<ProfileViewModel>().profile;
                context.read<RecommendationViewModel>().addCustomFood(food);
                context.read<RecommendationViewModel>().generate(
                      profile,
                      context.read<DiaryViewModel>(),
                      trigger: 'catalog_change',
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${food.name} added to database')),
                );
              },
              child: const Text('Save custom food'),
            ),
          ],
        ),
      ),
    );
  }
}
