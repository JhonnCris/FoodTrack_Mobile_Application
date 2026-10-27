import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import 'widgets/common_widgets.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final profileVm = context.watch<ProfileViewModel>();
    final p = profileVm.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (profileVm.saving || profileVm.hasPendingSave)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MaterialBanner(
                content: Text(profileVm.saving ? 'Saving profile changes…' : profileVm.saveError!),
                leading: Icon(profileVm.saving ? Icons.sync : Icons.cloud_off_outlined),
                actions: [if (profileVm.hasPendingSave) TextButton(onPressed: profileVm.retrySave, child: const Text('Retry'))],
              ),
            ),
          const SectionHeader('Daily targets'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _row('Calories', '${p.calorieTarget.toStringAsFixed(0)} kcal'),
                _row('Protein', '${p.proteinTarget.toStringAsFixed(0)} g'),
                _row('Carbs', '${p.carbsTarget.toStringAsFixed(0)} g'),
                _row('Fat', '${p.fatTarget.toStringAsFixed(0)} g'),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    p.targetsAreEstimated
                        ? 'Updated automatically from your profile.'
                        : 'Custom targets set by you.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${p.age} years · ${p.heightCm.toStringAsFixed(0)} cm · ${p.weightKg.toStringAsFixed(1)} kg',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showProfileDetails(context),
            ),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _editTargets(context),
            child: const Text('Set custom targets'),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<SessionViewModel>().signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'FoodTrack prototype · Not medical advice',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  void _showProfileDetails(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Consumer<ProfileViewModel>(
        builder: (context, profileVm, _) {
          final p = profileVm.profile;
          return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(p.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('${p.age} years · ${p.heightCm.toStringAsFixed(0)} cm · '
                  '${p.weightKg.toStringAsFixed(1)} kg'),
              const SizedBox(height: 16),
              DropdownButtonFormField<FitnessGoal>(
                initialValue: p.goal,
                decoration: const InputDecoration(labelText: 'Goal'),
                items: FitnessGoal.values
                    .map((goal) =>
                        DropdownMenuItem(value: goal, child: Text(goal.label)))
                    .toList(),
                onChanged: (goal) {
                  if (goal != null) vm.update((profile) => profile.goal = goal);
                },
              ),
              const SizedBox(height: 12),
              const Text('Activity level',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ActivityLevel.values
                    .map((activity) => ChoiceChip(
                          label: Text(activity.label),
                          selected: p.activity == activity,
                          onSelected: (_) => vm.update(
                              (profile) => profile.activity = activity),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DietPreference>(
                initialValue: p.diet,
                decoration: const InputDecoration(labelText: 'Diet preference'),
                items: DietPreference.values
                    .map((diet) =>
                        DropdownMenuItem(value: diet, child: Text(diet.label)))
                    .toList(),
                onChanged: (diet) {
                  if (diet != null) vm.update((profile) => profile.diet = diet);
                },
              ),
              const SizedBox(height: 20),
              const Text('Allergies',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Select all that apply, or add a specific allergy.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              ...ProfileViewModel.allergyCategories.entries.expand((group) => [
                    Text(group.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: group.value
                          .map((allergy) => FilterChip(
                                label: Text(allergy.replaceAll('_', ' ')),
                                selected: p.allergies.contains(allergy),
                                onSelected: (_) => vm.toggleAllergy(allergy),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                  ]),
              if (p.allergies.any((allergy) =>
                  !ProfileViewModel.commonAllergens.contains(allergy))) ...[
                const Text('Other / specific allergies',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: p.allergies
                      .where((allergy) =>
                          !ProfileViewModel.commonAllergens.contains(allergy))
                      .map((allergy) => InputChip(
                            label: Text(allergy),
                            onDeleted: () => vm.toggleAllergy(allergy),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => _addSpecificAllergy(sheetContext),
                icon: const Icon(Icons.add),
                label: const Text('Add a specific allergy'),
              ),
              const SizedBox(height: 16),
              const Text('Foods you dislike (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ...p.dislikedFoods.map((food) => InputChip(
                        label: Text(food),
                        onDeleted: () =>
                            vm.update((profile) => profile.dislikedFoods.remove(food)),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add food'),
                    onPressed: () => _addDislike(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _editBasics(sheetContext),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit basic details'),
              ),
            ]),
          ),
        ),
          );
        },
      ),
    );
  }

  void _editBasics(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    final p = vm.profile;
    final name = TextEditingController(text: p.name);
    final age = TextEditingController(text: '${p.age}');
    final h = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    final w = TextEditingController(text: p.weightKg.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Edit basics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: h,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Height (cm)'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextField(
                    controller: w,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Weight (kg)'))),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              vm.update((x) {
                x.name = name.text.trim().isEmpty ? x.name : name.text.trim();
                final enteredAge = int.tryParse(age.text);
                if (enteredAge != null && enteredAge >= 12 && enteredAge <= 120) {
                  final now = DateTime.now();
                  x.birthDate = DateTime(now.year - enteredAge, x.birthDate.month, x.birthDate.day);
                }
                x.heightCm = double.tryParse(h.text) ?? x.heightCm;
                x.weightKg = double.tryParse(w.text) ?? x.weightKg;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ]),
      ),
    );
  }

  void _addSpecificAllergy(BuildContext context) {
    final controller = TextEditingController();
    var category = 'Food or ingredient';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add a specific allergy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('For example: banana, sesame, or a medication ingredient.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Allergy category'),
              items: const [
                DropdownMenuItem(
                    value: 'Food or ingredient',
                    child: Text('Food or ingredient')),
                DropdownMenuItem(
                    value: 'Medication', child: Text('Medication')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) =>
                  setSheetState(() => category = value ?? category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Specific allergy',
                hintText: 'e.g. Banana',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final allergy = controller.text.trim().toLowerCase();
                if (allergy.isEmpty) return;
                final vm = sheetContext.read<ProfileViewModel>();
                if (!vm.profile.allergies.contains(allergy)) {
                  vm.toggleAllergy(allergy);
                }
                Navigator.pop(sheetContext);
              },
              child: const Text('Save allergy'),
            ),
          ]),
        ),
      ),
    );
  }

  void _addDislike(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add disliked food',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Food name (e.g. mushrooms)',
              hintText: 'Anything you prefer not to see in recommendations',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) {
                context
                    .read<ProfileViewModel>()
                    .update((x) => x.dislikedFoods.add(v));
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ]),
      ),
    );
  }

  void _editTargets(BuildContext context) {
    final vm = context.read<ProfileViewModel>();
    final p = vm.profile;
    final cal = TextEditingController(text: p.calorieTarget.toStringAsFixed(0));
    final pro = TextEditingController(text: p.proteinTarget.toStringAsFixed(0));
    final carb = TextEditingController(text: p.carbsTarget.toStringAsFixed(0));
    final fat = TextEditingController(text: p.fatTarget.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Custom daily targets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Overrides the estimated targets (FR-22).',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          TextField(
              controller: cal,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories (kcal)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: pro,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Protein (g)'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: carb,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbs (g)'))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: fat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Fat (g)'))),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              vm.setCustomTargets(
                calories: double.tryParse(cal.text) ?? p.calorieTarget,
                protein: double.tryParse(pro.text) ?? p.proteinTarget,
                carbs: double.tryParse(carb.text) ?? p.carbsTarget,
                fat: double.tryParse(fat.text) ?? p.fatTarget,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Custom targets saved')),
              );
            },
            child: const Text('Save targets'),
          ),
        ]),
      ),
    );
  }
}
