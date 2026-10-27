import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:viva_la_resistance/app_config.dart';
import 'package:viva_la_resistance/config_builder.dart';

AppConfig _config() {
  return AppConfig.fromJson({
    'name': 'Test',
    'address': '203.0.113.10',
    'port': 443,
    'uuid': '00000000-0000-0000-0000-000000000000',
    'flow': 'xtls-rprx-vision',
    'server_name': 'vpn.example.com',
    'reality_public_key': 'PUBLIC_KEY_PLACEHOLDER',
    'reality_short_id': '0123456789abcdef',
  });
}

void main() {
  test('domain mode uses rule sets and directs everything else', () {
    final content = ConfigBuilder.build(
      config: _config(),
      services: {ServiceId.youtube, ServiceId.instagram},
      mode: TunnelMode.domains,
      workingPath: '/tmp/engine/working',
    );
    final root = jsonDecode(content) as Map<String, dynamic>;

    final outbound = (root['outbounds'] as List).first as Map;
    expect(outbound['type'], 'vless');
    expect((outbound['tls'] as Map)['reality'], isA<Map>());

    final route = root['route'] as Map;
    expect(route['final'], 'direct');
    final ruleSets = (route['rule_set'] as List).cast<Map>();
    expect(ruleSets.map((item) => item['tag']), [
      'geosite-youtube',
      'geosite-instagram',
    ]);
    expect(
      ruleSets.first['path'],
      '/tmp/engine/working/rule-sets/geosite-youtube.srs',
    );
  });

  test('app mode proxies all traffic and has no rule sets', () {
    final content = ConfigBuilder.build(
      config: _config(),
      services: {ServiceId.youtube},
      mode: TunnelMode.apps,
      workingPath: '/tmp/engine/working',
    );
    final root = jsonDecode(content) as Map<String, dynamic>;
    final route = root['route'] as Map;

    expect(route['final'], 'proxy');
    expect(route.containsKey('rule_set'), isFalse);
    expect((root['dns'] as Map)['final'], 'dns-proxy');
  });
}
