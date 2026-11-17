import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'wardrobe_models.dart';

class WardrobeStore {
  WardrobeStore({String? apiBaseUrl}) : apiBaseUrl = (apiBaseUrl ?? const String.fromEnvironment('WARDROBE_API_URL')).trim();

  static const _storageKey = 'thread-wardrobe-native-v1';
  final String apiBaseUrl;
  String? lastSyncError;
  bool lastLoadFromRemote = false;
  bool lastLoadHadData = false;

  bool get canSync => apiBaseUrl.isNotEmpty && _currentUserId() != null;

  String get syncStatus {
    if (apiBaseUrl.isEmpty) return 'Local only';
    if (_currentUserId() == null) return 'Sign in to sync';
    return lastSyncError == null ? 'Synced' : 'Sync pending';
  }

  Future<WardrobeData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final userId = _currentUserId();
    lastSyncError = null;
    lastLoadFromRemote = false;
    lastLoadHadData = false;
    if (userId == null) {
      final cached = preferences.getString(_storageKey);
      if (cached == null) return WardrobeData();
      try {
        lastLoadHadData = true;
        return WardrobeData.decode(cached);
      } on FormatException catch (error) {
        lastSyncError = 'Saved wardrobe data could not be read: ${error.message}';
        return WardrobeData();
      }
    }
    final userStorageKey = '$_storageKey:$userId';
    final cached = preferences.getString(userStorageKey);
    WardrobeData? local;
    if (cached != null) {
      try {
        local = WardrobeData.decode(cached);
        lastLoadHadData = true;
      } on FormatException {
        await preferences.remove(userStorageKey);
        lastSyncError = 'Saved wardrobe data could not be read.';
      }
    }

    if (apiBaseUrl.isNotEmpty) {
      final pendingSyncKey = '$userStorageKey:pending-sync';
      final accessToken = _currentAccessToken();
      if (preferences.getBool(pendingSyncKey) == true && local != null && accessToken != null) {
        final syncError = await _upload(local, accessToken);
        if (syncError == null) {
          await preferences.remove(pendingSyncKey);
          lastSyncError = null;
          lastLoadFromRemote = true;
          return local;
        }
        lastSyncError = syncError;
        return local;
      }
      try {
        if (accessToken == null) {
          lastSyncError = 'There is no active sign-in session to sync this wardrobe.';
          return local ?? WardrobeData();
        }
        final response = await http.get(
          Uri.parse('$apiBaseUrl/api/state'),
          headers: {'authorization': 'Bearer $accessToken'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic> && decoded['items'] is List) {
            final data = WardrobeData.fromJson(decoded);
            await preferences.setString(userStorageKey, data.encode());
            await preferences.remove(pendingSyncKey);
            lastSyncError = null;
            lastLoadFromRemote = true;
            lastLoadHadData = true;
            return data;
          }
          lastSyncError = 'The wardrobe API returned an invalid state document.';
        } else {
          lastSyncError = 'The wardrobe API could not load your data (HTTP ${response.statusCode}).';
        }
      } catch (error) {
        lastSyncError = 'Could not load the shared wardrobe: $error';
      }
    }

    return local ?? WardrobeData();
  }

  Future<void> save(WardrobeData data) async {
    final encoded = data.encode();
    final preferences = await SharedPreferences.getInstance();
    final session = _currentSession();
    lastSyncError = null;
    if (session == null) {
      await preferences.setString(_storageKey, encoded);
      if (apiBaseUrl.isNotEmpty) lastSyncError = 'There is no active sign-in session to sync this wardrobe.';
      return;
    }
    final userStorageKey = '$_storageKey:${session.user.id}';
    final pendingSyncKey = '$userStorageKey:pending-sync';
    await preferences.setString(userStorageKey, encoded);
    if (apiBaseUrl.isEmpty) return;

    final syncError = await _upload(data, session.accessToken);
    if (syncError == null) {
      await preferences.remove(pendingSyncKey);
    } else {
      lastSyncError = syncError;
      await preferences.setBool(pendingSyncKey, true);
    }
  }

  Future<String?> _upload(WardrobeData data, String accessToken) async {
    try {
      final response = await http
          .put(
            Uri.parse('$apiBaseUrl/api/state'),
            headers: {
              'authorization': 'Bearer $accessToken',
              'content-type': 'application/json',
            },
            body: data.encode(),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return 'The wardrobe API could not save your data (HTTP ${response.statusCode}).';
      }
      return null;
    } catch (error) {
      return 'Could not sync your wardrobe: $error';
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
