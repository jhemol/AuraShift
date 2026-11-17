import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wardrobe_models.dart';

class WardrobeStore {
  WardrobeStore({String? apiBaseUrl}) : apiBaseUrl = (apiBaseUrl ?? const String.fromEnvironment('WARDROBE_API_URL')).trim();

  static const _storageKey = 'thread-wardrobe-native-v1';
  final String apiBaseUrl;

  Future<WardrobeData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    if (userId == null) return WardrobeData();
    final userStorageKey = '$_storageKey:$userId';
    final cached = preferences.getString(userStorageKey);
    WardrobeData? local;
    if (cached != null) {
      try {
        local = WardrobeData.decode(cached);
      } on FormatException {
        await preferences.remove(_storageKey);
      }
    }

    if (apiBaseUrl.isNotEmpty) {
      try {
        final accessToken = _currentAccessToken();
        if (accessToken == null) return local ?? WardrobeData();
        final response = await http.get(
          Uri.parse('$apiBaseUrl/api/state'),
          headers: {'authorization': 'Bearer $accessToken'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['items'] is List) {
            final data = WardrobeData.fromJson(decoded);
            await preferences.setString(userStorageKey, data.encode());
            return data;
          }
        }
      } catch (_) {
        // Keep the native app usable offline or when the API is unreachable.
      }
    }

    return local ?? WardrobeData();
  }

  Future<void> save(WardrobeData data) async {
    final encoded = data.encode();
    final preferences = await SharedPreferences.getInstance();
    final session = _currentSession();
    if (session == null) {
      await preferences.setString(_storageKey, encoded);
      return;
    }
    await preferences.setString('$_storageKey:${session.user.id}', encoded);
    if (apiBaseUrl.isEmpty) return;

    try {
      await http
          .put(
            Uri.parse('$apiBaseUrl/api/state'),
            headers: {
              'authorization': 'Bearer ${session.accessToken}',
              'content-type': 'application/json',
            },
            body: encoded,
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Local persistence remains the source of truth while offline.
    }
  }

  String? _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Session? _currentSession() {
    try {
      return Supabase.instance.client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  String? _currentAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
