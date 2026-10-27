import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/pending_profile_store.dart';
import '../data/profile_repository.dart';
import '../models/user_profile.dart';

enum ProfileSaveState { saved, saving, offlinePending, failed }

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(this._repo, this._client, this._pendingStore) {
    _authSubscription = _client.auth.onAuthStateChange.listen((_) => load());
    load();
  }

  final ProfileRepository _repo;
  final SupabaseClient _client;
  final PendingProfileStore _pendingStore;
  late final StreamSubscription<AuthState> _authSubscription;
  Timer? _saveTimer;
  bool _savePending = false;

  UserProfile profile = UserProfile();
  bool onboarded = false;
  bool loading = true;
  ProfileSaveState saveState = ProfileSaveState.saved;
  String? saveError;
  bool get saving => saveState == ProfileSaveState.saving;
  bool get hasPendingSave => saveState == ProfileSaveState.offlinePending || saveState == ProfileSaveState.failed;

  static const commonAllergens = ['egg', 'milk', 'peanut', 'soy', 'fish', 'shellfish', 'wheat', 'tree_nuts'];
  static const allergyCategories = {
    'Dairy & eggs': ['milk', 'egg'],
    'Nuts & legumes': ['peanut', 'tree_nuts'],
    'Seafood': ['fish', 'shellfish'],
    'Grains & soy': ['wheat', 'soy'],
  };

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      profile = UserProfile();
      onboarded = false;
      saveState = ProfileSaveState.saved;
      loading = false;
      notifyListeners();
      return;
    }
    try {
      try {
        final remote = await _repo.load();
        if (remote != null) {
          profile = remote;
          onboarded = remote.onboardingCompletedAt != null;
        } else {
          profile = UserProfile();
          onboarded = false;
        }
      } catch (_) {
        // Continue to the durable queue when the network is unavailable.
      }
      final pending = await _pendingStore.load(userId);
      if (pending != null) {
        profile = pending.profile;
        onboarded = pending.onboarded;
        _savePending = true;
        saveState = ProfileSaveState.offlinePending;
        unawaited(_save());
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void update(void Function(UserProfile) change) {
    change(profile);
    if (profile.targetsAreEstimated) profile.recalculateTargets();
    _scheduleSave();
  }

  void toggleAllergy(String allergy) {
    profile.allergies.contains(allergy) ? profile.allergies.remove(allergy) : profile.allergies.add(allergy);
    _scheduleSave();
  }

  Future<void> completeOnboarding() async {
    profile.recalculateTargets();
    profile.onboardingCompletedAt ??= DateTime.now().toUtc();
    onboarded = true;
    _savePending = true;
    await _save();
  }

  void setCustomTargets({required double calories, required double protein, required double carbs, required double fat}) {
    profile
      ..calorieTarget = calories
      ..proteinTarget = protein
      ..carbsTarget = carbs
      ..fatTarget = fat
      ..targetsAreEstimated = false;
    _scheduleSave();
  }

  void _scheduleSave() {
    _savePending = true;
    saveError = null;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 650), _save);
    notifyListeners();
  }

  Future<void> retrySave() {
    _savePending = true;
    return _save();
  }

  Future<void> onAppResumed() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final pending = await _pendingStore.load(userId);
    if (pending == null) return;
    profile = pending.profile;
    onboarded = pending.onboarded;
    _savePending = true;
    await _save();
  }

  Future<void> _save() async {
    if (!_savePending) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _saveTimer?.cancel();
    _savePending = false;
    final pending = PendingProfileWrite(userId: userId, profile: profile.copy(), onboarded: onboarded);
    await _pendingStore.save(pending);
    saveState = ProfileSaveState.saving;
    saveError = null;
    notifyListeners();
    try {
      await _repo.save(pending.profile, onboarded: pending.onboarded);
      await _pendingStore.clearIfCurrent(pending);
      saveState = ProfileSaveState.saved;
    } catch (_) {
      _savePending = true;
      saveState = ProfileSaveState.offlinePending;
      saveError = 'Changes are saved on this device and will retry when you reconnect.';
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }
}
