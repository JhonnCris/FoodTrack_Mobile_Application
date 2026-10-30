import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
import '../data/auth_repository.dart';
import '../data/food_repository.dart';
import '../data/meal_repository.dart';
import '../data/pending_profile_store.dart';
import '../data/profile_repository.dart';

/// Application dependencies that require an initialized Supabase client.
///
/// Keeping the client here makes the startup boundary explicit: UI code can
/// only receive these services after Supabase initialization has succeeded.
class AppServices {
  AppServices(SupabaseClient client, {PendingProfileStore? pendingProfileStore})
    : this._(client, pendingProfileStore ?? PendingProfileStore.memory());

  AppServices._(this.client, this.pendingProfileStore)
    : authRepository = AuthRepository(client),
      foodRepository = FoodRepository(client),
      mealRepository = MealRepository(client),
      profileRepository = ProfileRepository(client),
      accountRepository = AccountRepository(client, pendingProfileStore);

  final SupabaseClient client;
  final AuthRepository authRepository;
  final AccountRepository accountRepository;
  final FoodRepository foodRepository;
  final MealRepository mealRepository;
  final ProfileRepository profileRepository;
  final PendingProfileStore pendingProfileStore;
}
