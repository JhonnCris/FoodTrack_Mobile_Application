# FoodTrack production-gap implementation plan

## Purpose

This plan closes the remaining production gaps identified after profile persistence, time-zone-aware daily queries, persisted favorites, and weekly reporting were added. It retains the current no-image scope.

## External-AI handoff contract

Use this section as context when asking an external AI to modify the project. It describes the current system rather than a desired redesign. Preserve these boundaries unless the prompt explicitly authorizes changing them.

### Repository structure

```text
FoodTrack/
├── lib/
│   ├── core/                 # AppConfig and theme only
│   ├── data/                 # Supabase repositories; no widgets
│   ├── models/               # Plain Dart domain/display models and enums
│   ├── viewmodels/           # ChangeNotifier state, orchestration, UI state
│   ├── views/                # Material screens and reusable view widgets
│   └── main.dart             # Supabase initialization and Provider graph
├── supabase/
│   └── migrations/           # Ordered, append-only schema/RPC migrations
├── test/                     # Flutter unit/widget tests
├── assets/images/foods/      # Local food images only; no image feature work planned
├── .env.example              # Configuration key names only; never put secrets here
├── pubspec.yaml              # Flutter dependencies
└── README.md                 # Project setup and developer documentation
```

### Flutter architecture and naming

| Layer | Naming rule | Current examples |
| --- | --- | --- |
| Model | Singular noun, snake_case filename, no Supabase client dependency | `UserProfile`, `Food`, `MealEntry`, `DailyNutrition` |
| Repository | `<Domain>Repository`; owns Supabase query/RPC mapping | `ProfileRepository`, `MealRepository`, `FoodRepository` |
| View model | `<Domain>ViewModel`; extends `ChangeNotifier`; owns loading/error/UI state | `ProfileViewModel`, `DiaryViewModel`, `RecommendationViewModel` |
| View | `<Domain>View`; contains presentation only | `ProfileView`, `ReportsView`, `LogView` |
| SQL RPC | Lowercase snake_case verb phrase | `create_meal_entry`, `update_meal_entry_servings`, `weekly_nutrition`, `replace_user_allergies`, `current_day_bounds` |
| Database tables | Lowercase plural snake_case | `user_profiles`, `meal_entries`, `meal_entry_nutrition` |
| Database columns | Lowercase snake_case; units in suffixes | `calories_kcal`, `protein_target_g`, `logged_at` |
| Dart enum persistence | Dart enum names may differ from database values only through an explicit `code`/`fromCode` mapper | `FitnessGoal.weightLoss` ↔ `weight_loss` |

Do not put Supabase calls directly in a view. Do not put widgets in repositories. Do not add stateful persistence logic to models.

### Current Provider graph

`FoodTrackApp` creates repositories first, then state holders:

```text
AuthRepository ──> SessionViewModel
ProfileRepository ──> ProfileViewModel ──> DiaryViewModel (time zone updates)
FoodRepository ─────┬────────────────────> DiaryViewModel (favorites)
MealRepository ─────┘
ProfileViewModel + DiaryViewModel + FoodRepository ──> RecommendationViewModel
FoodRepository ──> FoodViewModel
```

Use `Provider`, `ChangeNotifierProvider`, and `ChangeNotifierProxyProvider` as in `lib/main.dart`. Do not replace this graph with a new state-management library as part of the planned gap work.

### Domain vocabulary

| App term | Definition | Database source |
| --- | --- | --- |
| Profile | User-controlled preferences, body data, targets, and time zone | `user_profiles` plus allergy/dislike child tables |
| Onboarding complete | `onboarding_completed_at` is non-null | `user_profiles.onboarding_completed_at` |
| Food | Current catalog/custom food definition | `foods` and lookup/join tables |
| Meal entry | A user logging a food at a time with servings | `meal_entries` |
| Meal snapshot | Nutrition captured when the entry is created; immutable historical source | `meal_entry_nutrition` |
| Favorite | A user-to-food relationship, not a recent meal | `user_favorites` |
| Known allergy | An allergen selected by canonical code and stored through `allergen_id` | `allergens`, `user_allergies.allergen_id` |
| Custom allergy | Free-text allergy that has no matching canonical allergen | `user_allergies.custom_name` |
| Recommendation event | An auditable generated set of up to five foods | `recommendation_events` |

### Current schema

#### Lookup/catalog tables

- `goals(code, display_name)`; valid seeded codes include `muscle`, `weight_loss`, `weight_gain`, `balanced`, `fiber`.
- `activity_levels(code, display_name, tdee_factor)`; codes: `sedentary`, `light`, `moderate`, `active`.
- `diet_preferences(code, display_name)`; codes: `none`, `vegetarian`, `vegan`, `pescatarian`.
- `diet_tags(code, display_name)`; food tags include `vegan`, `vegetarian`, `pescatarian`.
- `food_categories(id, code, display_name)`; `custom` is the fallback category for private custom foods.
- `allergens(id, code, display_name)`; canonical codes are `egg`, `milk`, `peanut`, `soy`, `fish`, `shellfish`, `wheat`, `tree_nuts`.
- `meal_types(code, display_name)`; codes: `breakfast`, `lunch`, `dinner`, `snack`.

#### User-owned tables

| Table | Primary identity | Important columns / constraints |
| --- | --- | --- |
| `user_profiles` | `user_id` (references `auth.users`) | `birth_date`, `sex` (`male`, `female`, `prefer_not_to_say`), goal/activity/diet codes, `timezone`, targets, `targets_are_estimated`, immutable `onboarding_completed_at` |
| `user_allergies` | generated `id` | Exactly one of `allergen_id` or `custom_name` must be present. |
| `user_disliked_foods` | generated `id` | Exactly one of `food_id` or `custom_name` must be present. Current UI writes custom names. |
| `user_favorites` | composite `(user_id, food_id)` | Favorite foods must load directly from this table. |
| `meal_entries` | generated `id` | `food_id`, `meal_type_code`, servings, `logged_at`; one user owns each entry. |
| `meal_entry_nutrition` | `meal_entry_id` | Captured macro/nutrition snapshot. Never recompute old entries from `foods`. |
| `recommendation_events` | generated `id` | User, trigger type, model version, daily calories, JSON recommendations, created time. |

#### Food tables

- `foods` is public catalog data or a private user-created food. Private rows must have `created_by_user_id = auth.uid()` and `visibility = 'private'`.
- `food_allergens(food_id, allergen_id)` maps food to canonical allergens.
- `food_diet_tags(food_id, diet_tag_code)` maps food to diet tags.
- Custom food creation must set `category_id` to a matching existing category or the seeded `custom` category.

### Auth, RLS, and RPC rules

- Auth is real Supabase email/password auth through `AuthRepository` and `SessionViewModel`; do not reintroduce mock credentials in onboarding.
- All user-owned tables have RLS. Client queries must rely on `auth.uid()` ownership instead of accepting another user ID as an input.
- Security-sensitive writes/calculations belong in RPCs. Existing RPCs are `create_meal_entry`, `update_meal_entry_servings`, `replace_user_allergies`, `weekly_nutrition`, and `current_day_bounds`.
- RPCs use `security invoker` unless a narrowly justified `security definer` procedure is required. Set an empty `search_path` in function definitions and qualify all database objects with `public.`.
- New RPCs must be revoked from `public` and granted only to `authenticated`.
- Always validate `auth.uid()` inside a write RPC before changing user-owned data.

### Time, dates, and units

- Store instants as UTC `timestamptz`; write `DateTime.now().toUtc()` from Flutter for logged events.
- The user profile's IANA time zone controls which meal entries count as today and which dates reports display.
- `Asia/Manila` is the current initial fallback only. Do not use device-local time to form report date boundaries.
- Use the existing unit suffixes exactly: `_kcal`, `_g`, `_mg`, `_kg`, `_cm`, `_at`.
- `birth_date` is the source of age. Do not add an `age` database column.

### Existing implementation constraints

- Do not modify an existing deployed migration. Add a later numbered migration instead.
- Do not remove existing RLS policies without a replacement in the same migration.
- Do not persist selected canonical allergies as `custom_name`; use `replace_user_allergies`.
- Do not derive favorite foods from recent entries.
- Do not overwrite `onboarding_completed_at` after first completion.
- Do not calculate report history from mutable `foods` rows; use `meal_entry_nutrition`.
- Do not exceed five returned recommendations.
- No food-image generation, image uploads, or storage-bucket work is in scope.

### Prompt template for an external AI

```text
You are modifying the FoodTrack Flutter + Supabase project.
Read IMPLEMENTATION_PLAN.md first and preserve the External-AI handoff contract.

Task: <describe one numbered plan item or a bounded subtask>

Rules:
- Keep the Provider/repository/view-model/view architecture.
- Add, never rewrite, Supabase migrations.
- Respect RLS, auth.uid() ownership, canonical allergy IDs, user time zones,
  and immutable meal snapshots.
- Do not add image work or real secrets.
- List every changed file and run Flutter analyzer/tests applicable to the task.
```

## Delivery order

1. Make startup configuration explicit and testable.
2. Move recommendation selection and history writes into Supabase.
3. Make profile changes durable across offline/restart scenarios.
4. Add monthly reporting from immutable meal snapshots.
5. Add database and Flutter tests around security-sensitive behavior.

Each stage should be independently deployable and verified before moving to the next.

---

## 1. Supabase startup configuration

### Problem

`main.dart` only initializes Supabase when compile-time values exist, but providers always read `Supabase.instance.client`. Running without `SUPABASE_URL` and `SUPABASE_ANON_KEY` can therefore fail with an uninitialized client rather than showing an actionable configuration screen.

### Implementation

- Introduce an `AppServices` or `AppBootstrap` boundary that exposes either initialized services or a configuration error.
- Render a simple configuration-error screen when Supabase values are unavailable; do not build repositories or view models in that state.
- Keep credentials compile-time only. Do not add secrets to source control.
- Update the widget-test bootstrap to supply a fake service layer instead of depending on `Supabase.instance`.

### Files affected

| File | Change |
| --- | --- |
| `lib/main.dart` | Gate providers behind successful Supabase initialization. |
| `lib/core/app_config.dart` | Add validation/error message helpers. |
| `lib/core/app_services.dart` | New: central dependency holder or testable service factory. |
| `lib/views/configuration_error_view.dart` | New: actionable missing-config screen. |
| `test/widget_test.dart` | Test both configuration and authenticated bootstrap paths. |
| `.env.example` | Document required compile-time values without real credentials. |

### Acceptance criteria

- App never accesses `Supabase.instance.client` before initialization.
- A developer gets a clear setup message when configuration is missing.
- Widget tests run without a live Supabase project.

---

## 2. Server-side recommendations and history deduplication

### Problem

Recommendation scoring currently runs in Flutter. It can be modified by a client and history persistence occurs separately from selecting results. Session-local deduplication does not protect against app restarts or concurrent devices.

### Implementation

- Add a `generate_recommendations` RPC that reads the authenticated user's profile, allergy rows, disliked foods, current-day snapshot totals, and accessible foods.
- Filter allergens and diet conflicts in SQL; score only server-visible foods and return at most five items.
- Derive a stable input signature in the RPC (profile preferences, current local date, current meal totals, scoring model version).
- Insert recommendation history only when that signature differs from the latest matching event; selection and history insert occur in the same transaction.
- Return recommendation data, reasons, and whether a new history event was recorded.
- Replace client scoring with a repository call. Keep the Flutter `Recommendation` model as a display model only.

### Files affected

| File | Change |
| --- | --- |
| `supabase/migrations/202610250005_recommendation_rpc.sql` | New: RPC, indexes, signature column, and permissions. |
| `supabase/migrations/202610250003_recommendation_history.sql` | Only amend through a follow-up migration; do not edit an already-deployed migration. |
| `lib/data/recommendation_repository.dart` | New: typed RPC adapter. |
| `lib/viewmodels/recommendation_viewmodel.dart` | Remove local scoring and delegate generation to the repository. |
| `lib/models/recommendation.dart` | New: presentation/result model, if extracted from the view model. |
| `lib/main.dart` | Register the recommendation repository. |
| `test/data/recommendation_repository_test.dart` | New: response mapping and error behavior tests. |
| `supabase/tests/recommendations.sql` | New: SQL/RLS behavior tests, if Supabase CLI tests are enabled. |

### Acceptance criteria

- A client cannot bypass allergy, diet, or private-food visibility rules.
- Results contain no more than five foods.
- Same input signature creates at most one history event, across app restarts.
- A manual refresh can return the same recommendations without duplicating history.

---

## 3. Durable offline profile-save queue

### Problem

The current retry state is memory-only. If the application is closed while offline, unsaved profile changes are lost.

### Implementation

- Add a small local pending-write store using `shared_preferences` (already in `pubspec.yaml`) with a versioned JSON payload.
- Save the latest profile snapshot locally before remote persistence; coalesce repeated changes to one pending record per signed-in user.
- On successful Supabase write, remove the corresponding local pending record.
- Retry on application resume, sign-in/session refresh, and user-initiated retry.
- Protect users by clearing a queued record when it belongs to a different authenticated user; never replay one user's profile onto another account.
- Surface save state (`saved`, `saving`, `offline pending`, `failed`) in the profile view.

### Files affected

| File | Change |
| --- | --- |
| `lib/data/profile_repository.dart` | Keep remote reads/writes only; return structured failure information where useful. |
| `lib/data/pending_profile_store.dart` | New: versioned per-user local queue. |
| `lib/viewmodels/profile_viewmodel.dart` | Queue, replay, and status coordination. |
| `lib/models/user_profile.dart` | Add serialization/clone helpers or a separate DTO. |
| `lib/views/profile_view.dart` | Show durable pending/error state and retry action. |
| `lib/main.dart` | Provide the pending store and app lifecycle resume handling. |
| `test/viewmodels/profile_viewmodel_test.dart` | New: coalescing, retry, sign-out, and cross-user isolation tests. |
| `test/data/pending_profile_store_test.dart` | New: serialization and version migration tests. |

### Acceptance criteria

- A profile edit made offline is retained after app restart.
- The queue replays only for the same authenticated user.
- A successful replay clears the local record.
- The UI never incorrectly claims an offline edit is saved remotely.

---

## 4. Monthly reports from meal snapshots

### Problem

The weekly report now uses immutable nutrition snapshots, but there is no monthly aggregation or range selector.

### Implementation

- Add a generic `nutrition_summary` RPC parameterized by time zone and date range, returning daily calorie and macro totals from `meal_entry_nutrition`.
- Validate maximum range length in SQL to avoid unbounded report queries.
- Add a report range selector (week/month) and loading, empty, and error states.
- Reuse the same server result model for the weekly chart and the monthly chart.
- Preserve zero-intake dates in the response so the chart is accurate and predictable.

### Files affected

| File | Change |
| --- | --- |
| `supabase/migrations/202610250006_reporting_ranges.sql` | New: range-based reporting RPC, indexes if query plans require them, permissions. |
| `lib/data/meal_repository.dart` | Replace the weekly-specific method with a range query adapter. |
| `lib/models/daily_nutrition.dart` | New: move `DailyNutrition` out of the repository. |
| `lib/viewmodels/diary_viewmodel.dart` | Cache/report loading by selected range. |
| `lib/views/reports_view.dart` | Range selector, loading/error/empty chart states, monthly display. |
| `test/data/meal_repository_test.dart` | New: RPC row mapping and zero-day behavior. |
| `supabase/tests/reporting.sql` | New: time-zone and snapshot aggregation cases. |

### Acceptance criteria

- Week and month totals are calculated from `meal_entry_nutrition`, not mutable food records.
- Dates follow `user_profiles.timezone`.
- A date with no meal entries appears as zero, not as a missing chart column.

---

## 5. Security and regression tests

### Problem

The project only has a basic widget startup test. Critical server behavior is not protected by automated tests.

### Implementation

- Add Dart unit tests with repository fakes for profile, diary, and recommendation view models.
- Add Supabase SQL integration tests with two test users to verify RLS isolation.
- Test immutable meal snapshots after a food is edited.
- Test known and custom allergies, diet exclusions, five-item recommendation limit, and event deduplication.
- Test expired session, offline queue, failed remote save, and successful replay.
- Run `flutter analyze`, `flutter test`, and Supabase tests in CI.

### Files affected

| File | Change |
| --- | --- |
| `test/widget_test.dart` | Replace the single startup assertion with real bootstrap coverage. |
| `test/viewmodels/*.dart` | New: profile, diary, and recommendation tests. |
| `test/data/*.dart` | New: repository mapping and failure tests. |
| `supabase/tests/*.sql` | New: RLS, snapshots, reporting, and recommendation tests. |
| `.github/workflows/ci.yml` | New or updated: analyzer, Flutter test, and database-test jobs. |
| `README.md` | Document local test and Supabase test commands. |

### Acceptance criteria

- CI rejects analyzer failures and regression-test failures.
- User A cannot read, write, or replay User B's data.
- Food edits never change historical logged nutrition.

---

## Intentional defaults to retain

- `Asia/Manila` remains the initial database/app fallback for this Philippines-focused product, but a stored per-user time zone overrides it after profile persistence.
- `Guest`, default body values, and estimated nutrition targets remain onboarding defaults only; they are not report or recommendation fixtures.
- The no-image scope remains unchanged.

## Deployment notes

- Add new Supabase migrations; never rewrite migrations that may already be applied to a shared project.
- Deploy and validate the database migration before releasing Flutter code that calls a new RPC.
- Roll out the durable profile queue before relying on background autosave for critical profile changes.
