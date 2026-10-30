import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodtrack/data/pending_profile_store.dart';
import 'package:foodtrack/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'keeps another account pending profile write during account lookup',
    () async {
      final store = PendingProfileStore.memory();
      final pending = PendingProfileWrite(
        userId: 'account-a',
        profile: UserProfile(name: 'Account A'),
        onboarded: true,
      );
      await store.save(pending);

      expect(await store.load('account-b'), isNull);
      expect((await store.load('account-a'))?.profile.name, 'Account A');
    },
  );

  test(
    'migrates a legacy plaintext record only after secure storage write',
    () async {
      final pending = PendingProfileWrite(
        userId: 'account-a',
        profile: UserProfile(name: 'Account A'),
        onboarded: true,
      );
      final encoded = jsonEncode(pending.toJson());
      SharedPreferences.setMockInitialValues({
        'foodtrack.pending_profile.v1': encoded,
      });
      final secureStorage = _MemorySecureValueStore();

      final store = await PendingProfileStore.create(
        secureStorage: secureStorage,
      );
      final preferences = await SharedPreferences.getInstance();

      expect(await store.load('account-a'), isNotNull);
      expect(secureStorage.values.values.single, encoded);
      expect(preferences.getString('foodtrack.pending_profile.v1'), isNull);
    },
  );

  test('preserves legacy plaintext when secure migration fails', () async {
    final pending = PendingProfileWrite(
      userId: 'account-a',
      profile: UserProfile(name: 'Account A'),
      onboarded: true,
    );
    final encoded = jsonEncode(pending.toJson());
    SharedPreferences.setMockInitialValues({
      'foodtrack.pending_profile.v1': encoded,
    });
    final secureStorage = _MemorySecureValueStore()..failWrites = true;

    await expectLater(
      PendingProfileStore.create(secureStorage: secureStorage),
      throwsA(isA<PlatformException>()),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('foodtrack.pending_profile.v1'), encoded);
  });

  test('saves queued profiles through secure storage', () async {
    final secureStorage = _MemorySecureValueStore();
    SharedPreferences.setMockInitialValues({});
    final store = await PendingProfileStore.create(
      secureStorage: secureStorage,
    );
    final pending = PendingProfileWrite(
      userId: 'account-a',
      profile: UserProfile(name: 'Account A'),
      onboarded: true,
    );

    await store.save(pending);

    expect(await store.load('account-a'), isNotNull);
    expect(secureStorage.values.keys, ['foodtrack.pending_profile.v1']);
  });
}

class _MemorySecureValueStore implements SecureValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw PlatformException(code: 'secure_write_failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
