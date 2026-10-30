import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class PendingProfileWrite {
  const PendingProfileWrite({
    required this.userId,
    required this.profile,
    required this.onboarded,
  });

  final String userId;
  final UserProfile profile;
  final bool onboarded;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'userId': userId,
    'onboarded': onboarded,
    'profile': profile.toJson(),
  };

  factory PendingProfileWrite.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['userId'] is! String ||
        json['profile'] is! Map) {
      throw const FormatException('Unsupported pending profile record');
    }
    return PendingProfileWrite(
      userId: json['userId'] as String,
      onboarded: json['onboarded'] as bool? ?? false,
      profile: UserProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
    );
  }
}

abstract interface class SecureValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _FlutterSecureValueStore implements SecureValueStore {
  _FlutterSecureValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// A one-record, versioned queue. It never returns a record for another user.
class PendingProfileStore {
  PendingProfileStore._({
    required this._secureStorage,
    required this._preferences,
  });

  PendingProfileStore.memory() : _secureStorage = null, _preferences = null;

  static const _key = 'foodtrack.pending_profile.v1';
  static const _legacyKey = 'foodtrack.pending_profile.v1';

  final SecureValueStore? _secureStorage;
  final SharedPreferences? _preferences;
  String? _memoryRecord;

  static Future<PendingProfileStore> create({
    SecureValueStore? secureStorage,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final store = PendingProfileStore._(
      secureStorage:
          secureStorage ??
          _FlutterSecureValueStore(const FlutterSecureStorage()),
      preferences: preferences,
    );
    await store._migrateLegacyRecord();
    return store;
  }

  Future<void> _migrateLegacyRecord() async {
    final secureStorage = _secureStorage;
    final preferences = _preferences;
    if (secureStorage == null || preferences == null) return;

    final secureRecord = await secureStorage.read(_key);
    if (secureRecord != null) {
      await _removeLegacyRecord(preferences);
      return;
    }

    final legacyRecord = preferences.getString(_legacyKey);
    if (legacyRecord == null) return;

    try {
      PendingProfileWrite.fromJson(
        Map<String, dynamic>.from(jsonDecode(legacyRecord) as Map),
      );
    } on FormatException {
      await _removeLegacyRecord(preferences);
      return;
    }

    await secureStorage.write(_key, legacyRecord);
    await _removeLegacyRecord(preferences);
  }

  Future<void> _removeLegacyRecord(SharedPreferences preferences) async {
    if (!await preferences.remove(_legacyKey)) {
      throw StateError('Could not remove the legacy plaintext profile queue.');
    }
  }

  Future<String?> _readRecord() async {
    final secureStorage = _secureStorage;
    if (secureStorage != null) return secureStorage.read(_key);
    return _memoryRecord;
  }

  Future<PendingProfileWrite?> load(String userId) async {
    final encoded = await _readRecord();
    if (encoded == null) return null;
    try {
      final write = PendingProfileWrite.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
      if (write.userId == userId) return write;
      return null;
    } on FormatException {
      await _remove();
      return null;
    }
  }

  Future<void> save(PendingProfileWrite write) async {
    final encoded = jsonEncode(write.toJson());
    final secureStorage = _secureStorage;
    if (secureStorage != null) {
      await secureStorage.write(_key, encoded);
    } else {
      _memoryRecord = encoded;
    }
  }

  Future<void> clearIfCurrent(PendingProfileWrite write) async {
    final current = await load(write.userId);
    if (current != null &&
        jsonEncode(current.toJson()) == jsonEncode(write.toJson())) {
      await _remove();
    }
  }

  Future<void> clearForUser(String userId) async {
    final encoded = await _readRecord();
    if (encoded == null) return;
    try {
      final write = PendingProfileWrite.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
      if (write.userId == userId) await _remove();
    } on FormatException {
      await _remove();
    }
  }

  Future<void> _remove() async {
    final secureStorage = _secureStorage;
    if (secureStorage != null) {
      await secureStorage.delete(_key);
    } else {
      _memoryRecord = null;
    }
  }
}
