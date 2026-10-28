import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import '../models/app_profile.dart';

// ---------------------------------------------------------------------------
// ProfileFetchException
// ---------------------------------------------------------------------------
// Typed error returned by fetchRemote(). Callers can switch on [kind] without
// string-matching exception messages.
// ---------------------------------------------------------------------------

enum ProfileFetchErrorKind {
  /// The server returned a non-2xx HTTP status.
  httpError,

  /// The request did not complete within the allowed time.
  timeout,

  /// The server response was not valid UTF-8 or was empty.
  invalidResponse,

  /// The fetched content was rejected by SingboxClient.checkConfig().
  invalidConfig,

  /// Any other transport-level error (DNS failure, TLS error, etc.).
  networkError,
}

class ProfileFetchException implements Exception {
  final ProfileFetchErrorKind kind;
  final String message;

  /// For [ProfileFetchErrorKind.httpError] — the raw HTTP status code.
  final int? statusCode;

  const ProfileFetchException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'ProfileFetchException(${kind.name}): $message';
}

// ---------------------------------------------------------------------------
// ProfileService
// ---------------------------------------------------------------------------
// NOTE: This class is part of the example application, NOT the SDK.
//
// The flutter_singbox_client SDK does not fetch, cache, or manage profiles.
// SingboxClient.connect() always requires a fully-resolved JSON string via
// SessionOptions.config. This service demonstrates one way to
// implement profile management and remote URL fetching in your own app.
// ---------------------------------------------------------------------------

class ProfileService {
  static const _keyProfiles = 'profiles_json';
  static const _keyNextId = 'profiles_next_id';

  static const _defaultTimeout = Duration(seconds: 15);
  static const _defaultUserAgent = 'flutter_singbox_client_example/1.0';

  final SharedPreferences _prefs;

  /// SDK client — used only to validate fetched config before caching.
  final SingboxClient _client;

  ProfileService._(this._prefs, this._client);

  static Future<ProfileService> create(SingboxClient client) async {
    final prefs = await SharedPreferences.getInstance();
    return ProfileService._(prefs, client);
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  List<AppProfile> list() {
    final raw = _prefs.getString(_keyProfiles);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AppProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  AppProfile? get(int id) => list().firstWhere(
        (p) => p.id == id,
        orElse: () => throw StateError('Profile $id not found'),
      );

  String? getContent(int id) {
    return list()
        .firstWhere((p) => p.id == id,
            orElse: () => throw StateError('not found'))
        .content;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<AppProfile> add({
    required String name,
    required AppProfileType type,
    String? content,
    String? remoteURL,
    bool autoUpdate = false,
    int autoUpdateIntervalSeconds = 3600,
  }) async {
    final profiles = list();
    final id = (_prefs.getInt(_keyNextId) ?? 1);
    _prefs.setInt(_keyNextId, id + 1);

    String? resolvedContent = content;
    if (type == AppProfileType.remote && remoteURL != null) {
      resolvedContent = await fetchRemote(remoteURL);
    }

    final profile = AppProfile(
      id: id,
      name: name,
      type: type,
      content: resolvedContent,
      remoteURL: remoteURL,
      autoUpdate: autoUpdate,
      autoUpdateIntervalSeconds: autoUpdateIntervalSeconds,
      lastUpdated: type == AppProfileType.remote ? DateTime.now() : null,
    );

    _save([...profiles, profile]);
    return profile;
  }

  Future<AppProfile> fetchAndUpdate(int id) async {
    final profiles = list();
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Profile $id not found');
    final profile = profiles[idx];
    if (profile.remoteURL == null) throw StateError('Profile has no remote URL');

    final content = await fetchRemote(profile.remoteURL!);
    final updated =
        profile.copyWith(content: content, lastUpdated: DateTime.now());
    profiles[idx] = updated;
    _save(profiles);
    return updated;
  }

  Future<AppProfile> updateLocal(int id, {required String name, required String content}) async {
    final profiles = list();
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Profile $id not found');
    final updated = profiles[idx].copyWith(name: name, content: content);
    profiles[idx] = updated;
    _save(profiles);
    return updated;
  }

  Future<AppProfile> updateRemote(int id, {
    required String name,
    required String url,
    required bool autoUpdate,
    required int autoUpdateIntervalSeconds,
  }) async {
    final profiles = list();
    final idx = profiles.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Profile $id not found');
    final updated = profiles[idx].copyWith(
      name: name,
      remoteURL: url,
      autoUpdate: autoUpdate,
      autoUpdateIntervalSeconds: autoUpdateIntervalSeconds,
    );
    profiles[idx] = updated;
    _save(profiles);
    return updated;
  }

  void delete(int id) {
    _save(list().where((p) => p.id != id).toList());
  }

  // ── Remote fetch ──────────────────────────────────────────────────────────
  //
  // NOTE: This method is intentionally part of the example app, not the SDK.
  //
  // flutter_singbox_client.SingboxClient does not fetch or cache remote
  // profiles. The SDK only accepts a resolved JSON string via
  // SessionOptions.config. This method shows a production-quality
  // pattern you can adapt in your own application:
  //
  //   1. Make a GET request with a timeout and custom headers.
  //   2. Validate the response status and body.
  //   3. Run checkConfig() to confirm the content is a valid Sing-box config
  //      BEFORE caching — so invalid content is rejected at fetch time, not
  //      at connect() time.
  //   4. Return the validated string for the caller to store and use.
  //
  // Errors are surfaced as [ProfileFetchException] with a typed [kind] field
  // so callers can handle each failure mode without string-matching.

  /// Fetches a remote Sing-box configuration from [url], validates it, and
  /// returns the resolved JSON string.
  ///
  /// The returned string is safe to pass directly to [SessionOptions.config].
  ///
  /// Throws [ProfileFetchException] on any failure — network error, HTTP error,
  /// timeout, empty response, or invalid Sing-box configuration.
  ///
  /// [headers] are merged on top of a default `User-Agent`. Use them to pass
  /// subscription tokens or other provider-required headers:
  ///
  /// ```dart
  /// final content = await profileService.fetchRemote(
  ///   'https://sub.example.com/config',
  ///   headers: {'Authorization': 'Bearer $token'},
  /// );
  /// ```
  Future<String> fetchRemote(
    String url, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const ProfileFetchException(
        ProfileFetchErrorKind.networkError,
        'Invalid URL: must begin with http:// or https://',
      );
    }

    final mergedHeaders = {
      'User-Agent': _defaultUserAgent,
      ...?headers,
    };

    final http.Response response;
    try {
      response = await http
          .get(uri, headers: mergedHeaders)
          .timeout(timeout);
    } on http.ClientException catch (e) {
      throw ProfileFetchException(
        ProfileFetchErrorKind.networkError,
        'Network error: ${e.message}',
      );
    } on Exception catch (e) {
      // Covers SocketException, TlsException, TimeoutException, etc.
      final msg = e.toString();
      final kind = msg.contains('timeout') || msg.contains('TimeoutException')
          ? ProfileFetchErrorKind.timeout
          : ProfileFetchErrorKind.networkError;
      throw ProfileFetchException(kind, msg);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ProfileFetchException(
        ProfileFetchErrorKind.httpError,
        'Server returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final body = response.body.trim();
    if (body.isEmpty) {
      throw const ProfileFetchException(
        ProfileFetchErrorKind.invalidResponse,
        'Server returned an empty response',
      );
    }

    try {
      await _client.checkConfig(body);
    } catch (e) {
      throw ProfileFetchException(
        ProfileFetchErrorKind.invalidConfig,
        e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString(),
      );
    }

    return body;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _save(List<AppProfile> profiles) {
    _prefs.setString(
      _keyProfiles,
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
  }
}
