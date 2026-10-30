# FoodTrack

## Backend setup

The Supabase backend schema is versioned in `supabase/migrations`. Food-image
storage is intentionally deferred until suitable images are available.

1. Create a Supabase project and authenticate with the Supabase CLI:
   `npx supabase login`.
2. From this directory, link the project with
   `npx supabase link --project-ref YOUR_PROJECT_REF`, then apply migrations
   with `npx supabase db push`.
3. Configure Flutter with the public project URL and publishable/anon key. Never
   put the service-role key in this application.
4. Seed reviewed foods through a follow-up migration. Every nutrition value must
   use the food's defined serving.
5. Before release, use two separate accounts to test RLS for profiles, favorites,
   custom foods, meal entries, and nutrition snapshots.

Database regression scripts are in `supabase/tests`. Run them against a local
or staging project only; they create synthetic users and roll back their
fixtures. For local testing, start Supabase and apply the migrations:

```text
npx supabase start
npx supabase db reset
psql --set ON_ERROR_STOP=1 --file supabase/tests/rls.sql "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
psql --set ON_ERROR_STOP=1 --file supabase/tests/recommendation_privacy.sql "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
psql --set ON_ERROR_STOP=1 --file supabase/tests/account_deletion.sql "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
```

Alternatively, run each script in the Supabase SQL Editor for a disposable
staging project. Do not run these checks against production; the account
deletion script deletes a synthetic Auth user as part of its rollback-only
trigger check.

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

## Account data export and deletion

The Profile screen can export the signed-in user's profile, preferences,
favorites, custom foods, meal history, and recommendation history as a JSON
file. The export can contain sensitive personal data; store and share it
carefully.

Recommendation history stores only event metadata and recommended food IDs.
It is automatically deleted after 90 days; this does not change the retention
of meals or other account data. Previously exported copies are not affected.

Account deletion uses the `delete-account` Edge Function and an Auth-user delete
trigger. The trigger removes rows that would otherwise block cascades inside
the same database transaction as Auth deletion, so failed Auth deletion does
not leave the app data partially removed. Deploy the function before applying
the migration:

```text
npx supabase functions deploy delete-account
npx supabase db push
```

The Edge Function verifies the caller's access token and requires password
reauthentication no more than 15 minutes old. The service-role key is used only
by the Edge Function and must never be embedded in the app. Live records are
deleted immediately; managed Supabase backups may retain deleted data until the
project's configured backup retention period expires.
Confirm that `SUPABASE_SERVICE_ROLE_KEY` is available to the Edge Function in
the Supabase Edge Function secrets settings before enabling account deletion.

Pending profile changes (including allergy and nutrition-target preferences)
are encrypted with the platform secure-storage facility instead of being kept
in plaintext preferences. Existing pending changes are migrated on startup and
their plaintext copy is removed only after the secure write succeeds. Android
app-data backups are disabled so device-bound encryption keys cannot be
restored without their original device. Linux desktop builds require the
Secret Service/libsecret runtime and development library. Web builds require
HTTPS (or localhost) for the browser secure-storage API.

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
