import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/app_services.dart';
import 'core/app_theme.dart';
import 'data/food_repository.dart';
import 'data/meal_repository.dart';
import 'data/auth_repository.dart';
import 'data/profile_repository.dart';
import 'data/pending_profile_store.dart';
import 'viewmodels/diary_viewmodel.dart';
import 'viewmodels/food_viewmodel.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/recommendation_viewmodel.dart';
import 'viewmodels/session_viewmodel.dart';
import 'views/auth_view.dart';
import 'views/configuration_error_view.dart';
import 'views/main_shell.dart';
import 'views/onboarding_view.dart';
import 'views/reset_password_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? initializationError;
  AppServices? services;
  if (!AppConfig.hasSupabase) {
    initializationError = AppConfig.supabaseConfigurationError;
  } else {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      services = AppServices(
        Supabase.instance.client,
        pendingProfileStore: await PendingProfileStore.create(),
      );
    } catch (_) {
      initializationError = 'Supabase could not be initialized. Check the URL and anon key.';
    }
  }
  runApp(FoodTrackApp(services: services, initializationError: initializationError));
}

class FoodTrackApp extends StatelessWidget {
  const FoodTrackApp({super.key, this.services, this.initializationError});

  final AppServices? services;
  final String? initializationError;

  @override
  Widget build(BuildContext context) {
    final configurationError = initializationError ??
        (services == null
            ? 'Supabase services are not initialized. ${AppConfig.supabaseConfigurationError}'
            : null);
    if (configurationError != null) {
      return MaterialApp(
        title: 'FoodTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ConfigurationErrorView(message: configurationError),
      );
    }
    return MultiProvider(
      providers: [
        Provider.value(value: services!.authRepository),
        ChangeNotifierProvider(create: (c) => SessionViewModel(c.read<AuthRepository>())),
        Provider.value(value: services!.foodRepository),
        Provider.value(value: services!.mealRepository),
        Provider.value(value: services!.profileRepository),
        ChangeNotifierProvider(create: (c) => ProfileViewModel(c.read<ProfileRepository>(), services!.client, services!.pendingProfileStore)),
        ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
        ChangeNotifierProxyProvider2<ProfileViewModel, SessionViewModel, DiaryViewModel>(
          create: (c) => DiaryViewModel(c.read<MealRepository>(), c.read<FoodRepository>(), services!.client),
          update: (_, profile, session, diary) {
            diary!.setSession(session.signedIn);
            diary.setTimezone(profile.profile.timezone);
            return diary;
          },
        ),
        ChangeNotifierProvider(
            create: (c) => FoodViewModel(c.read<FoodRepository>())),
        ChangeNotifierProxyProvider3<ProfileViewModel, DiaryViewModel, SessionViewModel, RecommendationViewModel>(
          create: (c) => RecommendationViewModel(c.read<FoodRepository>(), services!.client),
          update: (_, profile, diary, session, recommendations) {
            recommendations!.setSession(session.signedIn);
            recommendations.generate(profile.profile, diary);
            return recommendations;
          },
        ),
      ],
      child: MaterialApp(
        title: 'FoodTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _ProfileSaveLifecycle(child: _Root()),
      ),
    );
  }
}

class _ProfileSaveLifecycle extends StatefulWidget {
  const _ProfileSaveLifecycle({required this.child});
  final Widget child;

  @override
  State<_ProfileSaveLifecycle> createState() => _ProfileSaveLifecycleState();
}

class _ProfileSaveLifecycleState extends State<_ProfileSaveLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ProfileViewModel>().onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shows onboarding until the profile is completed, then the main app.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    if (session.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (session.passwordRecoveryInProgress) return const ResetPasswordView();
    if (!session.signedIn) return const AuthView();
    final onboarded = context.select<ProfileViewModel, bool>((p) => p.onboarded);
    return onboarded ? const MainShell() : const OnboardingView();
  }
}
