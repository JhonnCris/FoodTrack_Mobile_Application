import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/diary_viewmodel.dart';
import '../viewmodels/recommendation_viewmodel.dart';
import 'widgets/common_widgets.dart';

class ForYouView extends StatelessWidget {
  const ForYouView({super.key});

  @override
  Widget build(BuildContext context) {
    final recVm = context.watch<RecommendationViewModel>();
    final profile = context.watch<ProfileViewModel>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('For you'),
        actions: [
          IconButton(
            tooltip: 'Regenerate',
            icon: const Icon(Icons.refresh),
            onPressed: () => recVm.generate(
              profile,
              context.read<DiaryViewModel>(),
              trigger: 'manual',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Goal: ${profile.goal.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          profile.diet.label +
                              (profile.allergies.isEmpty
                                  ? ''
                                  : ' · avoiding ${profile.allergies.join(', ')}'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (recVm.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No matches. Try loosening your filters.'),
              ),
            ),
          ...recVm.items.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FoodImage(food: r.food, compact: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.food.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${r.food.servingLabel} · ${r.food.calories.toStringAsFixed(0)} kcal · '
                                  'P ${r.food.protein.toStringAsFixed(0)}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Why: ${r.reason}'),
                      if (r.food.indicators.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.food.indicators
                              .map(IndicatorChip.new)
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  showAddToLogSheet(context, r.food),
                              child: const Text('Add to log'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(
            'For general nutrition information only; not medical advice. Allergen '
            'filtering depends on available data and cannot guarantee a food is '
            'allergen-free. Check labels and consult a qualified professional when needed.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
