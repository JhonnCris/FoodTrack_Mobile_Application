// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:foodtrack/core/app_services.dart';
import 'package:foodtrack/main.dart';

void main() {
  testWidgets('shows setup instructions when services are unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FoodTrackApp());

    expect(find.text('Configuration required'), findsOneWidget);
    expect(find.textContaining('flutter run --dart-define-from-file'), findsOneWidget);
  });

  testWidgets('starts with injected Supabase services without global initialization',
      (WidgetTester tester) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

    await tester.pumpWidget(FoodTrackApp(services: AppServices(client)));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
