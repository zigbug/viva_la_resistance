import 'dart:convert';

import 'package:flutter/services.dart';

class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

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
      ],
      ServiceId.instagram: const ['com.instagram.android'],
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

  static Future<AppConfig> load() async {
    String raw;
    try {
      raw = await rootBundle.loadString(localAsset);
    } catch (_) {
      throw ConfigException(
        'Не найден $localAsset.\n\n'
        'Скопируйте app/assets/config.example.json в '
        'app/assets/config.local.json и заполните параметры сервера.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw ConfigException(
        'Некорректный JSON в $localAsset: ${error.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ConfigException('$localAsset должен содержать JSON-объект.');
    }

    final config = AppConfig.fromJson(decoded);
    config.validate();
    return config;
  }

  void validate() {
    if (address.isEmpty || address == '0.0.0.0') {
      throw ConfigException('Укажите адрес сервера в $localAsset.');
    }
    if (port < 1 || port > 65535) {
      throw ConfigException('Порт сервера должен быть от 1 до 65535.');
    }
    if (!_uuidPattern.hasMatch(uuid)) {
      throw ConfigException('Укажите корректный UUID в $localAsset.');
    }
    if (serverName.isEmpty || !serverName.contains('.')) {
      throw ConfigException('Укажите server_name (домен) в $localAsset.');
    }
    if (realityPublicKey.isEmpty ||
        realityPublicKey == 'REPLACE_WITH_PUBLIC_KEY') {
      throw ConfigException('Укажите reality_public_key в $localAsset.');
    }
    if (realityShortId.isEmpty) {
      throw ConfigException('Укажите reality_short_id в $localAsset.');
    }
  }

  List<String> packagesFor(ServiceId service) => packages[service] ?? const [];

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
}
