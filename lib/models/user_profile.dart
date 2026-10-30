enum FitnessGoal { muscle, weightLoss, weightGain, balanced, fiber }

extension FitnessGoalX on FitnessGoal {
  String get label => switch (this) {
    FitnessGoal.muscle => 'Build muscle',
    FitnessGoal.weightLoss => 'Manage weight',
    FitnessGoal.weightGain => 'Gain weight',
    FitnessGoal.balanced => 'Balanced diet',
    FitnessGoal.fiber => 'More fiber',
  };
  String get code => switch (this) {
    FitnessGoal.weightLoss => 'weight_loss',
    FitnessGoal.weightGain => 'weight_gain',
    _ => name,
  };
  static FitnessGoal fromCode(String? value) => switch (value) {
    'weight_loss' => FitnessGoal.weightLoss,
    'weight_gain' => FitnessGoal.weightGain,
    'muscle' => FitnessGoal.muscle,
    'fiber' => FitnessGoal.fiber,
    _ => FitnessGoal.balanced,
  };
}

enum ActivityLevel { sedentary, light, moderate, active }

extension ActivityLevelX on ActivityLevel {
  String get label => switch (this) {
    ActivityLevel.sedentary => 'Sedentary',
    ActivityLevel.light => 'Lightly active',
    ActivityLevel.moderate => 'Moderately active',
    ActivityLevel.active => 'Very active',
  };
  double get factor => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
  };
}

enum DietPreference { none, vegetarian, vegan, pescatarian }

extension DietPreferenceX on DietPreference {
  String get label => switch (this) {
    DietPreference.none => 'No preference',
    DietPreference.vegetarian => 'Vegetarian',
    DietPreference.vegan => 'Vegan',
    DietPreference.pescatarian => 'Pescatarian',
  };
}

enum ProfileSex { male, female, preferNotToSay }

extension ProfileSexX on ProfileSex {
  String get label => switch (this) {
    ProfileSex.male => 'Male',
    ProfileSex.female => 'Female',
    ProfileSex.preferNotToSay => 'Prefer not to say',
  };
  String get code => switch (this) {
    ProfileSex.preferNotToSay => 'prefer_not_to_say',
    _ => name,
  };
  static ProfileSex fromCode(String? value) => switch (value) {
    'male' => ProfileSex.male,
    'female' => ProfileSex.female,
    _ => ProfileSex.preferNotToSay,
  };
}

class UserProfile {
  String name;
  DateTime birthDate;
  double heightCm;
  double weightKg;
  ProfileSex sex;
  FitnessGoal goal;
  ActivityLevel activity;
  DietPreference diet;
  Set<String> allergies;
  Set<String> dislikedFoods;
  String timezone;
  double calorieTarget;
  double proteinTarget;
  double carbsTarget;
  double fatTarget;
  bool targetsAreEstimated;

  /// Null means the user is still in onboarding. Once set it must not change.
  DateTime? onboardingCompletedAt;
  UserProfile({
    this.name = 'Guest',
    DateTime? birthDate,
    this.heightCm = 168,
    this.weightKg = 62,
    this.sex = ProfileSex.male,
    this.goal = FitnessGoal.balanced,
    this.activity = ActivityLevel.light,
    this.diet = DietPreference.none,
    Set<String>? allergies,
    Set<String>? dislikedFoods,
    this.timezone = 'Asia/Manila',
    this.calorieTarget = 2000,
    this.proteinTarget = 100,
    this.carbsTarget = 250,
    this.fatTarget = 65,
    this.targetsAreEstimated = true,
    this.onboardingCompletedAt,
  }) : birthDate = birthDate ?? DateTime(DateTime.now().year - 21, 1, 1),
       allergies = allergies ?? {},
       dislikedFoods = dislikedFoods ?? {};
  int get age {
    final now = DateTime.now();
    return now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
  }

  bool get isMale => sex == ProfileSex.male;
  set isMale(bool value) => sex = value ? ProfileSex.male : ProfileSex.female;
  UserProfile copy() => UserProfile.fromJson(toJson());
  Map<String, dynamic> toJson() => {
    'name': name,
    'birthDate': birthDate.toIso8601String(),
    'heightCm': heightCm,
    'weightKg': weightKg,
    'sex': sex.code,
    'goal': goal.code,
    'activity': activity.name,
    'diet': diet.name,
    'allergies': allergies.toList()..sort(),
    'dislikedFoods': dislikedFoods.toList()..sort(),
    'timezone': timezone,
    'calorieTarget': calorieTarget,
    'proteinTarget': proteinTarget,
    'carbsTarget': carbsTarget,
    'fatTarget': fatTarget,
    'targetsAreEstimated': targetsAreEstimated,
    'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
  };
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'Guest',
    birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 168,
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 62,
    sex: ProfileSexX.fromCode(json['sex'] as String?),
    goal: FitnessGoalX.fromCode(json['goal'] as String?),
    activity:
        ActivityLevel.values
            .where((value) => value.name == json['activity'])
            .firstOrNull ??
        ActivityLevel.light,
    diet:
        DietPreference.values
            .where((value) => value.name == json['diet'])
            .firstOrNull ??
        DietPreference.none,
    allergies: (json['allergies'] as List? ?? const [])
        .whereType<String>()
        .toSet(),
    dislikedFoods: (json['dislikedFoods'] as List? ?? const [])
        .whereType<String>()
        .toSet(),
    timezone: json['timezone'] as String? ?? 'Asia/Manila',
    calorieTarget: (json['calorieTarget'] as num?)?.toDouble() ?? 2000,
    proteinTarget: (json['proteinTarget'] as num?)?.toDouble() ?? 100,
    carbsTarget: (json['carbsTarget'] as num?)?.toDouble() ?? 250,
    fatTarget: (json['fatTarget'] as num?)?.toDouble() ?? 65,
    targetsAreEstimated: json['targetsAreEstimated'] as bool? ?? true,
    onboardingCompletedAt: DateTime.tryParse(
      json['onboardingCompletedAt'] as String? ?? '',
    ),
  );
  void recalculateTargets() {
    final sexAdjustment = sex == ProfileSex.male ? 5 : -161;
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexAdjustment;
    var tdee = bmr * activity.factor;
    switch (goal) {
      case FitnessGoal.weightLoss:
        tdee -= 400;
      case FitnessGoal.weightGain:
        tdee += 400;
      case FitnessGoal.muscle:
        tdee += 200;
      default:
        break;
    }
    calorieTarget = tdee.roundToDouble();
    final proteinPerKg = goal == FitnessGoal.muscle ? 1.8 : 1.2;
    proteinTarget = (weightKg * proteinPerKg).roundToDouble();
    fatTarget = (calorieTarget * .28 / 9).roundToDouble();
    carbsTarget = ((calorieTarget - proteinTarget * 4 - fatTarget * 9) / 4)
        .roundToDouble();
    targetsAreEstimated = true;
  }
}
