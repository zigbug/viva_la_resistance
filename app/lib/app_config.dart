import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ServerConfigRequired implements Exception {
  ServerConfigRequired(this.message, this.config);
  final String message;
  final AppConfig config;
  @override
  String toString() => message;
}

enum ServiceId { youtube, instagram }

extension ServiceIdInfo on ServiceId {
  String get label => switch (this) {
    ServiceId.youtube => 'YouTube',
    ServiceId.instagram => 'Instagram',
  };

  String get ruleSetTag => switch (this) {
    ServiceId.youtube => 'geosite-youtube',
    ServiceId.instagram => 'geosite-instagram',
  };

  String get assetFile => '$ruleSetTag.srs';
}

class AppConfig {
  AppConfig({
    required this.name,
    required this.address,
    required this.port,
    required this.uuid,
    required this.flow,
    required this.serverName,
    required this.realityPublicKey,
    required this.realityShortId,
    required this.defaultServices,
    required this.packages,
  });

  static const localAsset = 'assets/config.local.json';

  final String name;
  final String address;
  final int port;
  final String uuid;
  final String flow;
  final String serverName;
  final String realityPublicKey;
  final String realityShortId;
  final Set<ServiceId> defaultServices;
  final Map<ServiceId, List<String>> packages;

  factory AppConfig.defaults() => AppConfig.fromJson(const {});

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final services = <ServiceId>{};
    final rawServices = json['services'];
    if (rawServices is Map) {
      for (final service in ServiceId.values) {
        if (rawServices[service.name] != false) {
          services.add(service);
        }
      }
    } else {
      services.addAll(ServiceId.values);
    }

    final rawPackages = json['packages'];
    final packages = <ServiceId, List<String>>{
      ServiceId.youtube: const [
        'com.google.android.youtube',
        'app.revanced.android.youtube',
        'com.google.android.apps.youtube.music',
        'com.google.android.apps.youtube.kids',
        'com.google.android.youtube.tv',
        'app.revanced.android.apps.youtube.music',
      ],
      ServiceId.instagram: const [
        'com.instagram.android',
        'com.instagram.lite',
      ],
    };
    if (rawPackages is Map) {
      for (final service in ServiceId.values) {
        final value = rawPackages[service.name];
        if (value is List && value.isNotEmpty) {
          packages[service] = value.whereType<String>().toList();
        }
      }
    }

    return AppConfig(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Viva la Resistance',
      address: (json['address'] as String? ?? '').trim(),
      port: (json['port'] as num?)?.toInt() ?? 443,
      uuid: (json['uuid'] as String? ?? '').trim(),
      flow: (json['flow'] as String? ?? 'xtls-rprx-vision').trim(),
      serverName: (json['server_name'] as String? ?? '').trim(),
      realityPublicKey: (json['reality_public_key'] as String? ?? '').trim(),
      realityShortId: (json['reality_short_id'] as String? ?? '').trim(),
      defaultServices: services,
      packages: packages,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'port': port,
        'uuid': uuid,
        'flow': flow,
        'server_name': serverName,
        'reality_public_key': realityPublicKey,
        'reality_short_id': realityShortId,
        'services': {
          for (final s in ServiceId.values) s.name: defaultServices.contains(s),
        },
        'packages': {
          for (final e in packages.entries) e.key.name: e.value,
        },
      };

  Map<String, dynamic> serverToJson() => {
        'address': address,
        'port': port,
        'uuid': uuid,
        'flow': flow,
        'server_name': serverName,
        'reality_public_key': realityPublicKey,
        'reality_short_id': realityShortId,
      };

  AppConfig copyWithServer({
    String? address,
    int? port,
    String? uuid,
    String? flow,
    String? serverName,
    String? realityPublicKey,
    String? realityShortId,
  }) {
    return AppConfig(
      name: name,
      address: address ?? this.address,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      flow: flow ?? this.flow,
      serverName: serverName ?? this.serverName,
      realityPublicKey: realityPublicKey ?? this.realityPublicKey,
      realityShortId: realityShortId ?? this.realityShortId,
      defaultServices: {...defaultServices},
      packages: {
        for (final e in packages.entries) e.key: List<String>.from(e.value),
      },
    );
  }

  static File serverConfigFile(String basePath) =>
      File(p.join(basePath, 'server_config.json'));

  static Future<AppConfig> load({required String basePath}) async {
    Map<String, dynamic> base = {};
    try {
      final raw = await rootBundle.loadString(localAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) base = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Base asset is optional for public builds; defaults will be used.
    }

    final merged = Map<String, dynamic>.from(base);
    try {
      final file = serverConfigFile(basePath);
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          for (final key in const [
            'address',
            'port',
            'uuid',
            'flow',
            'server_name',
            'reality_public_key',
            'reality_short_id',
          ]) {
            if (decoded.containsKey(key)) merged[key] = decoded[key];
          }
        }
      }
    } catch (_) {
      // Ignore broken user override; user can re-enter in UI.
    }

    final config = AppConfig.fromJson(merged);
    final serverError = config.serverValidationError();
    if (serverError != null) {
      throw ServerConfigRequired(serverError, config);
    }
    return config;
  }

  Future<void> saveServer(String basePath) async {
    final file = serverConfigFile(basePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(serverToJson()),
    );
  }

  String? serverValidationError() {
    if (address.isEmpty || address == '0.0.0.0') {
      return 'Укажите адрес сервера (IP или домен VPS).';
    }
    if (port < 1 || port > 65535) {
      return 'Порт сервера должен быть от 1 до 65535.';
    }
    if (!_uuidPattern.hasMatch(uuid)) {
      return 'Укажите корректный UUID.';
    }
    if (serverName.isEmpty || !serverName.contains('.')) {
      return 'Укажите SNI / server_name (домен).';
    }
    if (realityPublicKey.isEmpty ||
        realityPublicKey == 'REPLACE_WITH_PUBLIC_KEY') {
      return 'Укажите Reality public key.';
    }
    if (realityShortId.isEmpty) {
      return 'Укажите Reality short id.';
    }
    return null;
  }

  void validate() {
    final err = serverValidationError();
    if (err != null) throw ConfigException(err);
  }

  List<String> packagesFor(ServiceId service) => packages[service] ?? const [];

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}
