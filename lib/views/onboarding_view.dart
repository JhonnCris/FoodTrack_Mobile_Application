import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../viewmodels/onboarding_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/recommendation_viewmodel.dart';
import '../viewmodels/diary_viewmodel.dart';

/// 5 short steps: profile -> body -> goal+activity -> diet+allergies -> review.
class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final ob = context.watch<OnboardingViewModel>();
    final profileVm = context.read<ProfileViewModel>();

    final steps = <Widget>[
      const _AccountStep(),
      const _BodyStep(),
      const _GoalStep(),
      const _DietStep(),
      const _ReviewStep(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: ob.isFirst
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: ob.back,
              ),
        title: Text(
          'Step ${ob.step + 1} of ${OnboardingViewModel.totalSteps}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: ob.progress, minHeight: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: steps[ob.step],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                onPressed: () {
                  if (ob.isLast) {
                    profileVm.completeOnboarding();
                    context.read<RecommendationViewModel>().generate(
                      profileVm.profile,
                      context.read<DiaryViewModel>(),
                      trigger: 'onboarding',
                    );
                  } else {
                    ob.next();
                  }
                },
                child: Text(ob.isLast ? 'Finish & see my plan' : 'Continue'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _title(String t, String sub) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text(sub, style: TextStyle(color: Colors.grey.shade700)),
    const SizedBox(height: 24),
  ],
);

class _AccountStep extends StatelessWidget {
  const _AccountStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Welcome to FoodTrack 🥗',
          'Tell us what to call you so we can personalize your food ideas.',
        ),
        TextField(
          onChanged: (v) =>
              vm.profile.name = v.trim().isEmpty ? 'Guest' : v.trim(),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ],
    );
  }
}

class _BodyStep extends StatelessWidget {
  const _BodyStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final p = vm.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'About you',
          'Used only to estimate your daily targets. You can change this anytime.',
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ProfileSex>(
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: ProfileSex.values
                .map(
                  (sex) => ButtonSegment(
                    value: sex,
                    label: Text(
                      sex.label,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
            selected: {p.sex},
            onSelectionChanged: (s) => vm.update((x) => x.sex = s.first),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Body measurements',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your exact details. You can update these later.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Date of birth'),
          subtitle: Text(
            '${p.birthDate.year}-${p.birthDate.month.toString().padLeft(2, '0')}-${p.birthDate.day.toString().padLeft(2, '0')} (${p.age} years old)',
          ),
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: p.birthDate,
              firstDate: DateTime(DateTime.now().year - 120),
              lastDate: DateTime(DateTime.now().year - 12),
            );
            if (selected != null) {
              vm.update((profile) => profile.birthDate = selected);
            }
          },
        ),
        const SizedBox(height: 12),
        _numberField(
          label: 'Height',
          initialValue: p.heightCm.toStringAsFixed(0),
          suffix: 'cm',
          decimal: true,
          onChanged: (value) {
            final height = double.tryParse(value);
            if (height != null && height >= 80 && height <= 250) {
              vm.update((profile) => profile.heightCm = height);
            }
          },
        ),
        const SizedBox(height: 12),
        _numberField(
          label: 'Weight',
          initialValue: p.weightKg.toStringAsFixed(1),
          suffix: 'kg',
          decimal: true,
          onChanged: (value) {
            final weight = double.tryParse(value);
            if (weight != null && weight >= 20 && weight <= 400) {
              vm.update((profile) => profile.weightKg = weight);
            }
          },
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required String initialValue,
    required String suffix,
    required ValueChanged<String> onChanged,
    bool decimal = false,
  }) => TextFormField(
    initialValue: initialValue,
    onChanged: onChanged,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        decimal ? RegExp(r'^\d*\.?\d{0,1}') : RegExp(r'^\d*'),
      ),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      helperText: decimal ? 'Use decimals if needed' : null,
    ),
  );
}

class _GoalStep extends StatelessWidget {
  const _GoalStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final p = vm.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Your goal', 'Pick the one that matters most right now.'),
        ...FitnessGoal.values.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: p.goal == g
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                minVerticalPadding: 14,
                leading: const Icon(Icons.flag_outlined),
                title: Text(
                  g.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: p.goal == g ? const Icon(Icons.check_circle) : null,
                onTap: () => vm.update((x) => x.goal = g),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Activity level',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ActivityLevel.values
              .map(
                (a) => ChoiceChip(
                  label: Text(a.label),
                  selected: p.activity == a,
                  onSelected: (_) => vm.update((x) => x.activity = a),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _DietStep extends StatelessWidget {
  const _DietStep();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final p = vm.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          'Diet & allergies',
          'We\'ll leave out foods that conflict with these.',
        ),
        const Text('Diet', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: DietPreference.values
              .map(
                (d) => ChoiceChip(
                  label: Text(d.label),
                  selected: p.diet == d,
                  onSelected: (_) => vm.update((x) => x.diet = d),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Allergies (optional)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ProfileViewModel.commonAllergens
              .map(
                (a) => FilterChip(
                  label: Text(a),
                  selected: p.allergies.contains(a),
                  onSelected: (_) => vm.toggleAllergy(a),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProfileViewModel>().profile;
    Widget row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title('Looks good?', 'You can go back to change anything.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                row('Name', p.name),
                row(
                  'Age / height / weight',
                  '${p.age} · ${p.heightCm.round()} cm · ${p.weightKg.round()} kg',
                ),
                row('Goal', p.goal.label),
                row('Activity', p.activity.label),
                row('Diet', p.diet.label),
                row(
                  'Allergies',
                  p.allergies.isEmpty ? 'None' : p.allergies.join(', '),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
