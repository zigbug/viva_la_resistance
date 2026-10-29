import 'dart:convert';

import 'package:path/path.dart' as p;

import 'app_config.dart';

enum TunnelMode { domains, apps }

extension TunnelModeInfo on TunnelMode {
  String get label => switch (this) {
    TunnelMode.domains => 'Домены',
    TunnelMode.apps => 'Приложения',
  };

  String get description => switch (this) {
    TunnelMode.domains =>
      'VPN для всех приложений. Через сервер идут только домены '
          'выбранных сервисов, остальной трафик — напрямую.',
    TunnelMode.apps =>
      'VPN только для выбранных приложений. Весь их трафик идёт '
          'через сервер, остальные приложения — напрямую.',
  };
}

class ConfigBuilder {
  const ConfigBuilder._();

  /// Core logging is switched off: the tunnel is verified, and on low-end
  /// hardware a debug log firehose costs more than the tunnel itself. Enable it
  /// together with `_captureCoreLogs` in vpn_controller.dart via
  /// `--dart-define=VIVA_CORE_LOGS=true`.
  static final bool enableCoreLogs =
      const bool.fromEnvironment('VIVA_CORE_LOGS');

  static String build({
    required AppConfig config,
    required Set<ServiceId> services,
    required TunnelMode mode,
    required String workingPath,
  }) {
    final ruleSets = <Map<String, Object?>>[];
    final routeRules = <Map<String, Object?>>[
      // Sniff must run BEFORE hijack-dns / rule_set matching:
      // protocol and domain are only known after sniffing. With this order
      // DNS queries to the TUN gateway (e.g. 172.19.0.2:53) get hijacked
      // instead of leaking to 'direct' via the ip_is_private rule below.
      {'action': 'sniff'},
      {'protocol': 'dns', 'action': 'hijack-dns'},
    ];
    final dnsRules = <Map<String, Object?>>[];

    if (mode == TunnelMode.domains) {
      for (final service in services) {
        ruleSets.add({
          'tag': service.ruleSetTag,
          'type': 'local',
          'format': 'binary',
          'path': p.join(workingPath, 'rule-sets', service.assetFile),
        });
        dnsRules.add({'rule_set': service.ruleSetTag, 'server': 'dns-proxy'});
      }
      routeRules.add({
        'rule_set': services.map((service) => service.ruleSetTag).toList(),
        'outbound': 'proxy',
      });
    }

    routeRules.add({'ip_is_private': true, 'outbound': 'direct'});

    final dns = <String, Object?>{
      'servers': [
        {'tag': 'dns-direct', 'type': 'udp', 'server': '77.88.8.8'},
        {
          'tag': 'dns-proxy',
          'type': 'udp',
          'server': '1.1.1.1',
          'detour': 'proxy',
        },
      ],
      'final': mode == TunnelMode.domains ? 'dns-direct' : 'dns-proxy',
      'strategy': 'prefer_ipv4',
    };
    if (dnsRules.isNotEmpty) {
      dns['rules'] = dnsRules;
    }

    final route = <String, Object?>{
      'rules': routeRules,
      'final': mode == TunnelMode.domains ? 'direct' : 'proxy',
      'auto_detect_interface': true,
      'default_domain_resolver': 'dns-direct',
    };
    if (ruleSets.isNotEmpty) {
      route['rule_set'] = ruleSets;
    }

    final tls = <String, Object?>{
      'enabled': true,
      'server_name': config.serverName,
      'utls': {'enabled': true, 'fingerprint': 'chrome'},
      'reality': {
        'enabled': true,
        'public_key': config.realityPublicKey,
        'short_id': config.realityShortId,
      },
    };

    final proxy = <String, Object?>{
      'type': 'vless',
      'tag': 'proxy',
      'server': config.address,
      'server_port': config.port,
      'uuid': config.uuid,
      'packet_encoding': 'xudp',
      'tls': tls,
    };
    if (config.flow.isNotEmpty) {
      proxy['flow'] = config.flow;
    }

    final root = <String, Object?>{
      'log': enableCoreLogs
          ? {'level': 'debug', 'timestamp': true}
          : {'disabled': true},
      'dns': dns,
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 9000,
          'auto_route': true,
          'strict_route': false,
          'stack': 'mixed',
          'endpoint_independent_nat': false,
        },
      ],
      'outbounds': [
        proxy,
        {'type': 'direct', 'tag': 'direct'},
      ],
      'route': route,
      'experimental': {
        'cache_file': {'enabled': true, 'path': 'cache.db'},
      },
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }
}
