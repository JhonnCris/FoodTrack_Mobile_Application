import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class PendingProfileWrite {
  const PendingProfileWrite({required this.userId, required this.profile, required this.onboarded});
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
    if (json['version'] != 1 || json['userId'] is! String || json['profile'] is! Map) {
      throw const FormatException('Unsupported pending profile record');
    }
    return PendingProfileWrite(
      userId: json['userId'] as String,
      onboarded: json['onboarded'] as bool? ?? false,
      profile: UserProfile.fromJson(Map<String, dynamic>.from(json['profile'] as Map)),
    );
  }
}

/// A one-record, versioned queue. It never returns a record for another user.
class PendingProfileStore {
  PendingProfileStore._(this._preferences);
  PendingProfileStore.memory() : _preferences = null;
  static const _key = 'foodtrack.pending_profile.v1';
  final SharedPreferences? _preferences;
  String? _memoryRecord;

  static Future<PendingProfileStore> create() async =>
      PendingProfileStore._(await SharedPreferences.getInstance());

  Future<PendingProfileWrite?> load(String userId) async {
    final encoded = _preferences?.getString(_key) ?? _memoryRecord;
    if (encoded == null) return null;
    try {
      final write = PendingProfileWrite.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
      if (write.userId == userId) return write;
    } on FormatException {
      // A corrupt or obsolete queue must never block the current account.
    }
    await _remove();
    return null;
  }

  Future<void> save(PendingProfileWrite write) async {
    final encoded = jsonEncode(write.toJson());
    if (_preferences != null) {
      await _preferences.setString(_key, encoded);
    } else {
      _memoryRecord = encoded;
    }
  }

  Future<void> clearIfCurrent(PendingProfileWrite write) async {
    final current = await load(write.userId);
    if (current != null && jsonEncode(current.toJson()) == jsonEncode(write.toJson())) {
      await _remove();
    }
  }

  Future<void> _remove() async {
    if (_preferences != null) {
      await _preferences.remove(_key);
    } else {
      _memoryRecord = null;
    }
  }
}
