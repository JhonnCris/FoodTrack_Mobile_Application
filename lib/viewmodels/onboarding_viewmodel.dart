import 'package:flutter/foundation.dart';

/// Only tracks which step the wizard is on. Answers are written straight
/// into ProfileViewModel as the user fills each step.
class OnboardingViewModel extends ChangeNotifier {
  static const totalSteps = 5;
  int _step = 0;
  int get step => _step;
  bool get isFirst => _step == 0;
  bool get isLast => _step == totalSteps - 1;
  double get progress => (_step + 1) / totalSteps;

  void next() {
    if (!isLast) {
      _step++;
      notifyListeners();
    }
  }

  void back() {
    if (!isFirst) {
      _step--;
      notifyListeners();
    }
  }
}
