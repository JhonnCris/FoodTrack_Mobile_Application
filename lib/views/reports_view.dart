import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/daily_nutrition.dart';
import '../viewmodels/diary_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryViewModel>();
    final profile = context.watch<ProfileViewModel>().profile;
    final data = diary.reportNutrition;
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportRange>(
            segments: ReportRange.values
                .map(
                  (range) =>
                      ButtonSegment(value: range, label: Text(range.label)),
                )
                .toList(),
            selected: {diary.reportRange},
            onSelectionChanged: (ranges) =>
                context.read<DiaryViewModel>().selectReportRange(ranges.first),
          ),
          const SizedBox(height: 16),
          if (diary.reportLoading)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (diary.reportError != null)
            _ReportMessage(
              icon: Icons.cloud_off_outlined,
              message: diary.reportError!,
              action: () => context.read<DiaryViewModel>().loadReport(),
              actionLabel: 'Retry',
            )
          else if (data.isEmpty)
            const _ReportMessage(
              icon: Icons.bar_chart_outlined,
              message: 'No report data is available for this range.',
            )
          else
            _ReportContent(data: data, target: profile.calorieTarget),
          const SizedBox(height: 12),
          Text(
            'Totals are calculated from saved meal nutrition snapshots. Empty dates are shown as zero.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.data, required this.target});
  final List<DailyNutrition> data;
  final double target;

  @override
  Widget build(BuildContext context) {
    final totalCalories = data.fold(0.0, (sum, day) => sum + day.calories);
    final average = totalCalories / data.length;
    final targetHits = data
        .where((day) => (day.calories - target).abs() <= target * .1)
        .length;
    final maxValue = [
      ...data.map((day) => day.calories),
      target,
    ].reduce((left, right) => left > right ? left : right);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _tile(
                'Average / day',
                '${average.toStringAsFixed(0)} kcal',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile('On target', '$targetHits of ${data.length} days'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tile(
                'Avg protein',
                _average((day) => day.protein),
                AppColors.protein,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tile(
                'Avg carbs',
                _average((day) => day.carbs),
                AppColors.carbs,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tile(
                'Avg fat',
                _average((day) => day.fat),
                AppColors.fat,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calories',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text('Daily target: ${target.toStringAsFixed(0)} kcal'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.map((day) => _bar(day, maxValue)).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(DailyNutrition day, double maxValue) {
    final height = maxValue == 0
        ? 4.0
        : (day.calories / maxValue * 126).clamp(4.0, 126.0);
    final over = day.calories > target * 1.1;
    return SizedBox(
      width: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            day.calories.toStringAsFixed(0),
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 4),
          Container(
            height: height,
            width: 24,
            decoration: BoxDecoration(
              color: over ? Colors.orange.shade400 : AppColors.green,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.Md().format(day.day),
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _average(double Function(DailyNutrition) value) =>
      '${(data.fold(0.0, (sum, day) => sum + value(day)) / data.length).toStringAsFixed(0)} g';

  Widget _tile(String label, String value, [Color? color]) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    ),
  );
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({
    required this.icon,
    required this.message,
    this.action,
    this.actionLabel,
  });
  final IconData icon;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            TextButton(onPressed: action, child: Text(actionLabel!)),
        ],
      ),
    ),
  );
}
