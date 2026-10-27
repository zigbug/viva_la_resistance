import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

import 'app_config.dart';
import 'config_builder.dart';
import 'engine_paths.dart';
import 'rule_sets.dart';

class VpnController extends ChangeNotifier {
  VpnController({
    required this.client,
    required this.paths,
    required this.config,
  });

  final SingboxClient client;
  final EnginePaths paths;
  final AppConfig config;

  ServiceState _state = ServiceState.stopped;
  Set<ServiceId> _services = <ServiceId>{};
  TunnelMode _mode = TunnelMode.domains;
  bool _busy = false;
  String? _error;
  TrafficStats _traffic = TrafficStats.zero;
  String? _coreVersion;

  StreamSubscription<ServiceState>? _stateSubscription;
  StreamSubscription<String>? _faultSubscription;
  StreamSubscription<TrafficStats>? _trafficSubscription;

  ServiceState get state => _state;
  Set<ServiceId> get services => Set.unmodifiable(_services);
  TunnelMode get mode => _mode;
  bool get busy => _busy;
  String? get error => _error;
  TrafficStats get traffic => _traffic;
  String? get coreVersion => _coreVersion;

  bool get isRunning => _state == ServiceState.started;
  bool get isBusy => _busy || _state.isTransitioning;
  bool get canEdit => _state.isIdle && !_busy;

  Future<void> init() async {
    _services = {...config.defaultServices};
    if (_services.isEmpty) {
      _services = ServiceId.values.toSet();
    }

    try {
      _state = await client.getServiceState();
      _coreVersion = await client.getCoreVersion();
    } catch (error) {
      _error = _humanize(error);
    }

    _stateSubscription = client.serviceStateStream.listen((state) {
      _state = state;
      if (state.isRunning || state.isIdle) {
        _busy = false;
      }
      notifyListeners();
    });

    _faultSubscription = client.faultStream.listen((message) {
      _busy = false;
      _error = message;
      notifyListeners();
    });

    _trafficSubscription = client.trafficStatsStream.listen((stats) {
      _traffic = stats;
      notifyListeners();
    });

    notifyListeners();
  }

  void setServiceEnabled(ServiceId service, bool enabled) {
    if (!canEdit) {
      return;
    }
    if (enabled) {
      _services.add(service);
    } else {
      _services.remove(service);
    }
    _error = null;
    notifyListeners();
  }

  void setMode(TunnelMode mode) {
    if (!canEdit) {
      return;
    }
    _mode = mode;
    _error = null;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_busy || _state.isTransitioning) {
      return;
    }
    if (_state.isRunning) {
      await disconnect();
    } else if (_state.isIdle) {
      await connect();
    }
  }

  Future<void> connect() async {
    if (_busy || !_state.isIdle) {
      return;
    }
    if (_services.isEmpty) {
      _error = 'Выберите хотя бы один сервис.';
      notifyListeners();
      return;
    }

    _busy = true;
    _error = null;
    _traffic = TrafficStats.zero;
    notifyListeners();

    try {
      if (_mode == TunnelMode.domains) {
        await installRuleSets(paths.working, _services);
      }

      final content = ConfigBuilder.build(
        config: config,
        services: _services,
        mode: _mode,
        workingPath: paths.working,
      );

      await client.checkConfig(content);

      final granted = await client.requestVPNPermission();
      if (!granted) {
        throw const VpnPermissionDenied();
      }

      // Always include our own package: if none of the target apps are
      // installed, Android must still have at least one allowed app, otherwise
      // it would route every app into the tunnel.
      final packages = <String>{
        'ru.server905911.viva',
        for (final service in _services) ...config.packagesFor(service),
      };

      await client.connect(
        SessionOptions(
          config: content,
          networkMode: NetworkMode.vpn,
          perAppProxy: _mode == TunnelMode.apps && packages.isNotEmpty
              ? PerAppProxyOptions(
                  mode: PerAppProxyMode.include,
                  packages: packages.toList(),
                )
              : null,
          notification: NotificationConfig(
            title: config.name,
            channelName: 'VPN',
            showTrafficStats: true,
            showStopButton: true,
            stopButtonLabel: 'Стоп',
          ),
        ),
      );
    } on VpnPermissionDenied catch (error) {
      _busy = false;
      _error = error.message;
      notifyListeners();
    } on PlatformException catch (error) {
      _busy = false;
      _error = error.message ?? error.code;
      notifyListeners();
    } catch (error) {
      _busy = false;
      _error = _humanize(error);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_busy || !_state.isRunning) {
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await client.disconnect();
    } catch (error) {
      _busy = false;
      _error = _humanize(error);
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  String _humanize(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
    return text;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _faultSubscription?.cancel();
    _trafficSubscription?.cancel();
    super.dispose();
  }
}

class VpnPermissionDenied implements Exception {
  const VpnPermissionDenied();

  String get message => 'Разрешение на VPN не выдано.';
}
