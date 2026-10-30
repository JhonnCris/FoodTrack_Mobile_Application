import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/food.dart';
import '../models/recipe_nutrition.dart';
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
      body: Column(
        children: [
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
            child: vm.loading
                ? const Center(child: CircularProgressIndicator())
                : vm.error != null
                ? _FoodLoadError(message: vm.error!, onRetry: vm.load)
                : vm.results.isEmpty
                ? _EmptyState(query: vm.query)
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
                            builder: (_) => FoodDetailView(food: f),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomFoodSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Create from ingredients'),
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
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey.shade500),
        const SizedBox(height: 8),
        Text(query.isEmpty ? 'No foods available' : 'No matches for “$query”'),
        const SizedBox(height: 4),
        Text(
          query.isEmpty
              ? 'Try again later or create a meal from ingredients.'
              : 'Try a different search or create a meal from ingredients.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    ),
  );
}

class _FoodLoadError extends StatelessWidget {
  const _FoodLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
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
                const SnackBar(
                  content: Text(
                    'Could not update favorites. Check your connection and try again.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            child: Text(
              'Serving size: ${food.servingLabel}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Center(
            child: FoodCompatibilityWarning(food: food, profile: profile),
          ),
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
              child: Column(
                children: [
                  row('Calories', '${food.calories.toStringAsFixed(0)} kcal'),
                  const Divider(),
                  row('Protein', '${food.protein} g'),
                  row('Carbs', '${food.carbs} g'),
                  row('Fat', '${food.fat} g'),
                  const Divider(),
                  row('Fiber', '${food.fiber} g'),
                  row('Sugar', '${food.sugar} g'),
                  row('Sodium', '${food.sodium.toStringAsFixed(0)} mg'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (food.allergens.isNotEmpty)
            Text(
              'Recorded allergens: ${food.allergens.join(', ')}',
              style: TextStyle(color: Colors.orange.shade800),
            ),
          const SizedBox(height: 4),
          Text(
            'Nutrition and allergen details are ${food.isVerified ? 'reviewed' : 'unverified'} '
            'and may vary by brand and preparation. An empty allergen list does not '
            'mean the food is allergen-free.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (food.nutritionSourceName != null ||
              food.allergenSourceName != null ||
              food.reviewedAt != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data provenance',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (food.nutritionSourceName != null)
                      SelectableText(
                        'Nutrition source: ${food.nutritionSourceName}'
                        '${food.nutritionSourceUrl == null ? '' : '\n${food.nutritionSourceUrl}'}',
                      ),
                    if (food.allergenSourceName != null)
                      SelectableText(
                        'Allergen source: ${food.allergenSourceName}'
                        '${food.allergenSourceUrl == null ? '' : '\n${food.allergenSourceUrl}'}',
                      ),
                    if (food.reviewedAt != null)
                      Text(
                        'Reviewed: ${food.reviewedAt!.toLocal().toString().split(' ').first}',
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => showAddToLogSheet(context, food),
            icon: const Icon(Icons.add),
            label: const Text('Add to log'),
          ),
        ],
      ),
    );
  }
}

/// Builds a custom recipe from foods with known catalog nutrition.
class _CustomFoodSheet extends StatefulWidget {
  const _CustomFoodSheet();

  @override
  State<_CustomFoodSheet> createState() => _CustomFoodSheetState();
}

class _CustomFoodSheetState extends State<_CustomFoodSheet> {
  final _name = TextEditingController();
  final _recipeServings = TextEditingController(text: '1');
  final List<_RecipeIngredientDraft> _ingredients = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _recipeServings.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }

  double? get _yield => double.tryParse(_recipeServings.text.trim());

  bool get _canEstimate {
    final yieldCount = _yield;
    return _ingredients.isNotEmpty &&
        yieldCount != null &&
        yieldCount.isFinite &&
        yieldCount > 0 &&
        _ingredients.every((ingredient) {
          final amount = ingredient.amount;
          return amount != null && amount.isFinite && amount > 0;
        });
  }

  RecipeNutrition? get _nutrition {
    if (!_canEstimate) return null;
    return RecipeNutrition.fromIngredients(
      _ingredients.map(
        (ingredient) => RecipeIngredient(
          food: ingredient.food,
          servings: ingredient.amount!,
        ),
      ),
      recipeServings: _yield!,
    );
  }

  Future<void> _addIngredient() async {
    final foodViewModel = context.read<FoodViewModel>();
    if (foodViewModel.loading) {
      _showMessage('Loading the food catalog. Try again in a moment.');
      return;
    }
    if (foodViewModel.foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The food catalog is not available. Check your connection and try again.',
          ),
        ),
      );
      return;
    }

    final food = await showDialog<Food>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final normalizedQuery = query.trim().toLowerCase();
            final foods = foodViewModel.foods
                .where(
                  (item) =>
                      normalizedQuery.isEmpty ||
                      item.name.toLowerCase().contains(normalizedQuery),
                )
                .toList();
            return AlertDialog(
              title: const Text('Choose an ingredient'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setDialogState(() => query = value),
                      decoration: const InputDecoration(
                        hintText: 'Search catalog',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: foods.isEmpty
                          ? const Center(
                              child: Text('No matching ingredients.'),
                            )
                          : ListView.builder(
                              itemCount: foods.length,
                              itemBuilder: (_, index) {
                                final food = foods[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(food.name),
                                  subtitle: Text(
                                    '${food.servingLabel} · ${food.calories.toStringAsFixed(0)} kcal',
                                  ),
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(food),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted || food == null) return;
    setState(() {
      _ingredients.add(
        _RecipeIngredientDraft(
          food: food,
          amountController: TextEditingController(text: '1'),
        ),
      );
    });
  }

  Future<void> _saveRecipe() async {
    final name = _name.text.trim();
    final yieldCount = _yield;
    if (name.isEmpty) {
      _showMessage('Add a name for your meal.');
      return;
    }
    if (_ingredients.isEmpty) {
      _showMessage('Add at least one ingredient.');
      return;
    }
    if (yieldCount == null || !yieldCount.isFinite || yieldCount <= 0) {
      _showMessage('Enter how many servings the recipe makes.');
      return;
    }
    if (!_ingredients.every((ingredient) {
      final amount = ingredient.amount;
      return amount != null && amount.isFinite && amount > 0;
    })) {
      _showMessage('Enter a valid amount for every ingredient.');
      return;
    }

    final nutrition = _nutrition!;
    final description =
        'Estimated from FoodTrack catalog ingredients: '
        '${_ingredients.map((ingredient) => '${ingredient.amount!.toStringAsFixed(ingredient.amount == ingredient.amount!.roundToDouble() ? 0 : 1)} × ${ingredient.food.name} (${ingredient.food.servingLabel})').join(', ')}.';
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final food = await context.read<FoodViewModel>().addCustom(
        name: name,
        category: 'Custom',
        servingLabel: '1 serving',
        description: description,
        calories: nutrition.calories,
        protein: nutrition.protein,
        carbs: nutrition.carbs,
        fat: nutrition.fat,
        fiber: nutrition.fiber,
        sugar: nutrition.sugar,
        sodium: nutrition.sodium,
      );
      if (!mounted) return;
      final profile = context.read<ProfileViewModel>().profile;
      context.read<RecommendationViewModel>().addCustomFood(food);
      context.read<RecommendationViewModel>().generate(
        profile,
        context.read<DiaryViewModel>(),
        trigger: 'catalog_change',
      );
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name saved with estimated nutrition per serving.'),
        ),
      );
    } catch (_) {
      _showMessage(
        'Could not save this meal. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = _nutrition;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create a meal from ingredients',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose ingredients from the food catalog. Nutrition is estimated automatically from each item’s serving size.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'For example, chicken and rice',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _recipeServings,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'How many servings does the whole recipe make?',
                helperText: 'Nutrition below is calculated per serving.',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingredients',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (_ingredients.isEmpty)
              Text(
                'Add foods such as rice, chicken, or vegetables. No calorie or protein entry is needed.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ingredient.food.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove ${ingredient.food.name}',
                            onPressed: () => setState(() {
                              _ingredients.removeAt(index).dispose();
                            }),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        'One catalog serving: ${ingredient.food.servingLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextField(
                        controller: ingredient.amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Amount in catalog servings',
                          hintText: 'For example, 1 or 0.5',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Add ingredient'),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated nutrition per serving',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (nutrition == null)
                      Text(
                        'Add ingredients and valid amounts to calculate nutrition.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      )
                    else
                      Text(
                        '${nutrition.calories.toStringAsFixed(0)} kcal · '
                        'Protein ${nutrition.protein.toStringAsFixed(1)} g · '
                        'Carbs ${nutrition.carbs.toStringAsFixed(1)} g · '
                        'Fat ${nutrition.fat.toStringAsFixed(1)} g · '
                        'Fiber ${nutrition.fiber.toStringAsFixed(1)} g · '
                        'Sugar ${nutrition.sugar.toStringAsFixed(1)} g · '
                        'Sodium ${nutrition.sodium.toStringAsFixed(0)} mg',
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Estimates use the catalog values and may differ from actual ingredients or cooking methods.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _saveRecipe,
              child: Text(_saving ? 'Saving…' : 'Save meal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeIngredientDraft {
  _RecipeIngredientDraft({required this.food, required this.amountController});

  final Food food;
  final TextEditingController amountController;
  double? get amount => double.tryParse(amountController.text.trim());

  void dispose() => amountController.dispose();
}
