# FoodTrack

## Backend setup

The Supabase backend schema is versioned in `supabase/migrations`. Food-image
storage is intentionally deferred until suitable images are available.

1. Create a Supabase project and install the Supabase CLI.
2. From this directory, run `supabase link --project-ref YOUR_PROJECT_REF`, then
   run `supabase db push`.
3. Configure Flutter with the public project URL and publishable/anon key. Never
   put the service-role key in this application.
4. Seed reviewed foods through a follow-up migration. Every nutrition value must
   use the food's defined serving.
5. Before release, use two separate accounts to test RLS for profiles, favorites,
   custom foods, meal entries, and nutrition snapshots.

The initial schema supports one diet preference per profile, private custom foods,
favorites, allergies, and captured per-serving nutrition for meal history.

Food catalog records remain unverified until nutrition and allergen references
have both been reviewed and recorded. Meal entries keep the per-serving nutrition
captured at logging time, so later food-catalog edits do not change historical
meals when their serving count is adjusted. Existing meal snapshots are
backfilled from their saved totals and serving counts; nutrition changes made
before that migration cannot be reconstructed.

Run with configuration supplied at launch, for example:

```text
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

Without those defines, the app shows a configuration screen and does not create
any Supabase-dependent repositories.

## Email confirmation and password recovery

Native builds receive Supabase email callbacks at `foodtrack://auth`; browser
builds return to the same web origin that requested the email. The app shows a
new-password screen only after Supabase reports a password-recovery callback.
In the Supabase Dashboard, go to **Authentication > URL Configuration** and add
`foodtrack://auth` and each deployed web app URL (for example,
`https://your-domain.example`) to **Additional Redirect URLs**. This must be
configured in the hosted project as well as in this repository;
`supabase/config.toml` only controls a local Supabase instance.

## Android release signing

Create an upload key once, keep it backed up securely, then copy
`android/key.properties.example` to `android/key.properties` and fill in the
matching values. Release builds intentionally fail until this file is present;
the debug key is never used for a release build.

```text
keytool -genkeypair -v -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Keep both `upload-keystore.jks` and `key.properties` out of source control.
