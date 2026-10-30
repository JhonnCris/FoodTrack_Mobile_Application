import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/pending_profile_store.dart';
import '../data/profile_repository.dart';
import '../models/user_profile.dart';

enum ProfileSaveState { saved, saving, offlinePending, failed }

enum ProfileLoadState { loading, loaded, failed }

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel(
    this._repo,
    SupabaseClient client,
    this._pendingStore, {
    String? Function()? currentUserId,
    Stream<void>? authStateChanges,
  }) : _currentUserId = currentUserId ?? (() => client.auth.currentUser?.id),
       _authStateChanges =
           authStateChanges ?? client.auth.onAuthStateChange.map((_) {}) {
    _authSubscription = _authStateChanges.listen((_) {
      if (_currentUserId() != _loadedUserId) {
        unawaited(load());
      }
    });
    unawaited(load());
  }

  final ProfileRepository _repo;
  final PendingProfileStore _pendingStore;
  final String? Function() _currentUserId;
  final Stream<void> _authStateChanges;
  late final StreamSubscription<void> _authSubscription;
  Timer? _saveTimer;
  bool _savePending = false;
  String? _loadedUserId;
  int _loadGeneration = 0;

  UserProfile profile = UserProfile();
  bool onboarded = false;
  bool loading = true;
  ProfileLoadState loadState = ProfileLoadState.loading;
  String? loadError;
  ProfileSaveState saveState = ProfileSaveState.saved;
  String? saveError;
  bool get saving => saveState == ProfileSaveState.saving;
  bool get hasPendingSave =>
      saveState == ProfileSaveState.offlinePending ||
      saveState == ProfileSaveState.failed;

  static const allergyCategories = {
    'Dairy & eggs': ['milk', 'egg'],
    'Nuts & legumes': ['peanut', 'tree_nuts'],
    'Seafood': ['fish', 'shellfish'],
    'Grains & soy': ['wheat', 'soy'],
  };

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final userId = _currentUserId();
    if (_loadedUserId != userId) {
      _loadedUserId = userId;
      profile = UserProfile();
      onboarded = false;
      _savePending = false;
      saveState = ProfileSaveState.saved;
      saveError = null;
    }
    loading = true;
    loadState = ProfileLoadState.loading;
    loadError = null;
    notifyListeners();
    if (userId == null) {
      profile = UserProfile();
      onboarded = false;
      saveState = ProfileSaveState.saved;
      loading = false;
      loadState = ProfileLoadState.loaded;
      notifyListeners();
      return;
    }
    try {
      final remote = await _repo.load(userId: userId);
      if (!_isCurrentLoad(generation, userId)) return;
      profile = remote ?? UserProfile();
      onboarded = remote?.onboardingCompletedAt != null;

      final pending = await _pendingStore.load(userId);
      if (!_isCurrentLoad(generation, userId)) return;
      loadState = ProfileLoadState.loaded;
      if (pending != null) {
        profile = pending.profile;
        onboarded = pending.onboarded;
        _savePending = true;
        saveState = ProfileSaveState.offlinePending;
        unawaited(_save());
      }
    } catch (_) {
      if (!_isCurrentLoad(generation, userId)) return;
      loadState = ProfileLoadState.failed;
      loadError =
          'Your profile could not be loaded. Check your connection and retry. '
          'Your saved profile has not been replaced.';
    } finally {
      if (_isCurrentLoad(generation, userId)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentLoad(int generation, String userId) =>
      generation == _loadGeneration && _currentUserId() == userId;

  void update(void Function(UserProfile) change) {
    if (loadState != ProfileLoadState.loaded) return;
    change(profile);
    if (profile.targetsAreEstimated) profile.recalculateTargets();
    _scheduleSave();
  }

  void toggleAllergy(String allergy) {
    if (loadState != ProfileLoadState.loaded) return;
    profile.allergies.contains(allergy)
        ? profile.allergies.remove(allergy)
        : profile.allergies.add(allergy);
    _scheduleSave();
  }

  Future<void> completeOnboarding() async {
    if (loadState != ProfileLoadState.loaded) {
      throw StateError('The profile must load before onboarding can be saved.');
    }
    profile.recalculateTargets();
    profile.onboardingCompletedAt ??= DateTime.now().toUtc();
    onboarded = true;
    _savePending = true;
    await _save();
  }

  void setCustomTargets({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    if (loadState != ProfileLoadState.loaded) return;
    profile
      ..calorieTarget = calories
      ..proteinTarget = protein
      ..carbsTarget = carbs
      ..fatTarget = fat
      ..targetsAreEstimated = false;
    _scheduleSave();
  }

  void _scheduleSave() {
    if (loadState != ProfileLoadState.loaded) return;
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
    if (_currentUserId() == null) return;
    await load();
  }

  Future<void> _save() async {
    if (!_savePending || loadState != ProfileLoadState.loaded) return;
    final userId = _currentUserId();
    if (userId == null) return;
    _saveTimer?.cancel();
    _savePending = false;
    final pending = PendingProfileWrite(
      userId: userId,
      profile: profile.copy(),
      onboarded: onboarded,
    );
    await _pendingStore.save(pending);
    if (_currentUserId() != userId) return;
    saveState = ProfileSaveState.saving;
    saveError = null;
    notifyListeners();
    try {
      await _repo.save(pending.profile, onboarded: pending.onboarded);
      if (_currentUserId() != userId) return;
      await _pendingStore.clearIfCurrent(pending);
      if (_currentUserId() != userId) return;
      saveState = ProfileSaveState.saved;
    } catch (_) {
      if (_currentUserId() != userId) return;
      _savePending = true;
      saveState = ProfileSaveState.offlinePending;
      saveError =
          'Changes are saved on this device and will retry when you reconnect.';
    } finally {
      if (_currentUserId() == userId) notifyListeners();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _saveTimer?.cancel();
    _authSubscription.cancel();
    super.dispose();
  }
}
