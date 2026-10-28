import 'package:flutter_test/flutter_test.dart';
import 'package:foodtrack/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('explains how to recover from an email rate limit', () {
    final message = friendlyAuthError(
      AuthException('email rate limit exceeded'),
    );

    expect(message, contains('wait'));
    expect(message, contains('inbox'));
    expect(message, isNot(contains('email rate limit exceeded')));
  });

  test('keeps actionable authentication errors understandable', () {
    expect(
      friendlyAuthError(AuthException('Invalid login credentials')),
      contains('Forgot password'),
    );
  });
}
