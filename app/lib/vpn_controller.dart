import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

import 'app_config.dart';
import 'config_builder.dart';
import 'engine_paths.dart';
import 'rule_sets.dart';

/// Core logs are only useful while checking that the tunnel works. They are
/// high volume (hundreds of entries per second on active traffic) and each
/// entry costs a platform-channel hop plus a Dart allocation, which is enough
/// to stall low-end TV boxes. The core itself is also configured with logging
/// disabled, so this subscription is normally never created.
///
/// Enable both sides with: `flutter run --dart-define=VIVA_CORE_LOGS=true`.
final bool _captureCoreLogs = const bool.fromEnvironment('VIVA_CORE_LOGS');

/// Maximum number of log entries to keep in memory.
const int _maxLogEntries = 2000;

/// Maximum number of connection entries to keep in memory.
const int _maxConnectionEntries = 500;

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

  final List<LogEntry> _logs = [];
  final List<ConnectionInfo> _connections = [];
  LogLevel _logFilterLevel = LogLevel.info;
  String _logSearchQuery = '';

  StreamSubscription<ServiceState>? _stateSubscription;
  StreamSubscription<String>? _faultSubscription;
  StreamSubscription<TrafficStats>? _trafficSubscription;
  StreamSubscription<List<LogEntry>>? _logSubscription;
  StreamSubscription<List<ConnectionInfo>>? _connectionSubscription;

  /// Connection events arrive dozens of times per second; rebuilding the whole
  /// UI for each of them stalls weak devices. The list is always updated, only
  /// the notification is coalesced (traffic updates also notify once a second).
  DateTime _lastConnectionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  ServiceState get state => _state;
  Set<ServiceId> get services => Set.unmodifiable(_services);
  TunnelMode get mode => _mode;
  bool get busy => _busy;
  String? get error => _error;
  TrafficStats get traffic => _traffic;
  String? get coreVersion => _coreVersion;

  /// All captured log entries (newest first).
  List<LogEntry> get logs => List.unmodifiable(_logs.reversed.toList());

  /// Filtered log entries based on current level and search query.
  List<LogEntry> get filteredLogs {
    final filtered = _logs.where((entry) {
      if (entry.level.index < _logFilterLevel.index) return false;
      if (_logSearchQuery.isNotEmpty) {
        final q = _logSearchQuery.toLowerCase();
        if (!entry.message.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
    return filtered.reversed.toList();
  }

  /// All captured connection entries (newest first).
  List<ConnectionInfo> get connections =>
      List.unmodifiable(_connections.reversed.toList());

  LogLevel get logFilterLevel => _logFilterLevel;
  String get logSearchQuery => _logSearchQuery;

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
      _addLog(
        LogEntry(
          level: LogLevel.info,
          message: 'Service state changed: ${state.name}',
          time: DateTime.now(),
        ),
      );
      if (state.isRunning || state.isIdle) {
        _busy = false;
      }
      notifyListeners();
    });

    _faultSubscription = client.faultStream.listen((message) {
      _busy = false;
      _error = message;
      _addLog(
        LogEntry(
          level: LogLevel.error,
          message: 'FAULT: $message',
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    });

    _trafficSubscription = client.trafficStatsStream.listen((stats) {
      _traffic = stats;
      notifyListeners();
    });

    // Core log stream - high volume, batched. Off unless explicitly enabled.
    if (_captureCoreLogs) {
      _logSubscription = client.coreLogStream.listen(
        (entries) {
          for (final entry in entries) {
            _addLog(entry);
          }
          notifyListeners();
        },
        onError: (error) {
          _addLog(
            LogEntry(
              level: LogLevel.error,
              message: 'Log stream error: $error',
              time: DateTime.now(),
            ),
          );
        },
      );
    }

    // Connection stream - every open/close event
    _connectionSubscription = client.connectionStream.listen(
      (conns) {
        // Index by id once per batch instead of scanning the whole list for
        // every event: the core emits dozens of events per second.
        var indexes = <String, int>{
          for (var i = 0; i < _connections.length; i++)
            _connections[i].id: i,
        };
        for (final conn in conns) {
          final idx = indexes[conn.id];
          if (idx != null) {
            _connections[idx] = conn;
            continue;
          }
          final before = _connections.length;
          _addConnection(conn);
          if (_connections.length <= before) {
            // The ring buffer dropped old entries, so indexes shifted.
            indexes = <String, int>{
              for (var i = 0; i < _connections.length; i++)
                _connections[i].id: i,
            };
          } else {
            indexes[conn.id] = _connections.length - 1;
          }
        }
        final now = DateTime.now();
        if (now.difference(_lastConnectionNotify) >=
            const Duration(milliseconds: 500)) {
          _lastConnectionNotify = now;
          notifyListeners();
        }
      },
      onError: (error) {
        _addLog(
          LogEntry(
            level: LogLevel.error,
            message: 'Connection stream error: $error',
            time: DateTime.now(),
          ),
        );
      },
    );

    notifyListeners();
  }

  void _addLog(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxLogEntries) {
      _logs.removeRange(0, _logs.length - _maxLogEntries);
    }
    final hint = _rknHint(entry.message);
    if (hint != null) {
      _logs.add(
        LogEntry(level: LogLevel.warn, message: hint, time: DateTime.now()),
      );
    }
  }

  /// Maps sing-box / Reality failures to a short diagnosis.
  ///
  /// A handshake that dies before the tunnel is up, or a reset right after
  /// ClientHello, is what an active probe / DPI drop looks like. A wrong
  /// SNI or short_id looks the same from the client, so the hint lists both.
  String? _rknHint(String message) {
    final text = message.toLowerCase();
    const markers = [
      'reality: processed invalid connection',
      'reality: failed',
      'tls handshake',
      'connection reset by peer',
      'connection refused',
      'i/o timeout',
      'context deadline exceeded',
      'no route to host',
      'network is unreachable',
      'eof',
    ];
    if (!markers.any(text.contains)) {
      return null;
    }
    if (text.contains('dns') || text.contains('lookup')) {
      return 'ПОХОЖЕ НА БЛОКИРОВКУ DNS: имя не резолвится. '
          'В режиме «Домены» DNS выбранных сервисов идёт через туннель — '
          'если туннель ещё не поднялся, это ожидаемо. Если уже подключён, '
          'РКН может резать DNS или сам 443.';
    }
    if (text.contains('reality') || text.contains('tls handshake')) {
      return 'ПОХОЖЕ НА ОБРЫВ REALITY: рукопожатие не прошло. '
          'Либо DPI/РКН режет ClientHello на 443, либо SNI/public key/short_id '
          'не совпадают с сервером. Сверьте server_name (vlr.905911.ru) '
          'и ключи в config.local.json.';
    }
    if (text.contains('timeout') || text.contains('deadline')) {
      return 'ТАЙМАУТ ДО СЕРВЕРА: пакеты до 443 не доходят или ответа нет. '
          'Так выглядит дроп на стороне провайдера/РКН, либо сервер недоступен.';
    }
    if (text.contains('reset') ||
        text.contains('refused') ||
        text.contains('eof')) {
      return 'СОЕДИНЕНИЕ ОБОРВАНО: RST/EOF до установки туннеля. '
          'Частый признак DPI. Если повторяется только на YouTube/Instagram '
          'после успешного connect — режут уже целевой трафик, не вход.';
    }
    return 'СЕТЬ НЕДОСТУПНА: нет маршрута до сервера. Проверьте мобильный '
        'интернет и что адрес в config.local.json — IP, а не заблокированное имя.';
  }

  void _addConnection(ConnectionInfo conn) {
    _connections.add(conn);
    if (_connections.length > _maxConnectionEntries) {
      _connections.removeRange(0, _connections.length - _maxConnectionEntries);
    }
    if (!_captureCoreLogs) return;
    // Mirror connection events into the journal only in diagnostics mode.
    _addLog(
      LogEntry(
        level: LogLevel.info,
        message: conn.isActive
            ? 'CONNECT ${conn.network.toUpperCase()} ${conn.domain.isNotEmpty ? conn.domain : conn.destination} → ${conn.outbound} (rule: ${conn.rule})'
            : 'CLOSE ${conn.network.toUpperCase()} ${conn.domain.isNotEmpty ? conn.domain : conn.destination} ↑${conn.uplinkTotalBytes} ↓${conn.downlinkTotalBytes}',
        time: DateTime.now(),
      ),
    );
  }

  void setLogFilterLevel(LogLevel level) {
    _logFilterLevel = level;
    notifyListeners();
  }

  void setLogSearchQuery(String query) {
    _logSearchQuery = query;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void clearConnections() {
    _connections.clear();
    notifyListeners();
  }

  /// Export logs as plain text for sharing/debugging.
  String exportLogs({bool filtered = true}) {
    final entries = filtered ? filteredLogs : logs.reversed.toList();
    final buffer = StringBuffer();
    buffer.writeln('Viva la Resistance — Core Logs');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Core: $_coreVersion');
    buffer.writeln('Mode: ${_mode.name}');
    buffer.writeln('Services: ${_services.map((s) => s.name).join(", ")}');
    buffer.writeln(
      'Filter: ${_logFilterLevel.name} ${_logSearchQuery.isNotEmpty ? "| search: $_logSearchQuery" : ""}',
    );
    buffer.writeln('─' * 60);
    for (final entry in entries) {
      buffer.writeln(
        '${entry.time.toIso8601String()} [${entry.level.name.toUpperCase()}] ${entry.message}',
      );
    }
    return buffer.toString();
  }

  /// Export connections as CSV for analysis.
  String exportConnectionsCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'id,time,closedAt,inbound,inboundType,network,source,destination,domain,protocol,user,outbound,outboundType,rule,chain,packageName,uplinkBytes,downlinkBytes',
    );
    for (final conn in _connections) {
      buffer.write('${conn.id},');
      buffer.write('${conn.createdAt.toIso8601String()},');
      buffer.write('${conn.closedAt?.toIso8601String() ?? ""},');
      buffer.write('${_csvEscape(conn.inbound)},');
      buffer.write('${_csvEscape(conn.inboundType)},');
      buffer.write('${_csvEscape(conn.network)},');
      buffer.write('${_csvEscape(conn.source)},');
      buffer.write('${_csvEscape(conn.destination)},');
      buffer.write('${_csvEscape(conn.domain)},');
      buffer.write('${_csvEscape(conn.protocol)},');
      buffer.write('${_csvEscape(conn.user)},');
      buffer.write('${_csvEscape(conn.outbound)},');
      buffer.write('${_csvEscape(conn.outboundType)},');
      buffer.write('${_csvEscape(conn.rule)},');
      buffer.write('${_csvEscape(conn.chain)},');
      buffer.write('${_csvEscape(conn.packageName ?? "")},');
      buffer.write('${conn.uplinkTotalBytes},');
      buffer.write('${conn.downlinkTotalBytes}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void setServiceEnabled(ServiceId service, bool enabled) {
    if (!canEdit) return;
    if (enabled) {
      _services.add(service);
    } else {
      _services.remove(service);
    }
    _error = null;
    notifyListeners();
  }

  void setMode(TunnelMode mode) {
    if (!canEdit) return;
    _mode = mode;
    _error = null;
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_busy || _state.isTransitioning) return;
    if (_state.isRunning) {
      await disconnect();
    } else if (_state.isIdle) {
      await connect();
    }
  }

  Future<void> connect() async {
    if (_busy || !_state.isIdle) return;
    if (_services.isEmpty) {
      _error = 'Выберите хотя бы один сервис.';
      notifyListeners();
      return;
    }

    _busy = true;
    _error = null;
    _traffic = TrafficStats.zero;
    _addLog(
      LogEntry(
        level: LogLevel.info,
        message: '=== CONNECT ATTEMPT ===',
        time: DateTime.now(),
      ),
    );
    _addLog(
      LogEntry(
        level: LogLevel.info,
        message:
            'Mode: ${_mode.name}, Services: ${_services.map((s) => s.name).join(", ")}',
        time: DateTime.now(),
      ),
    );
    notifyListeners();

    try {
      if (_mode == TunnelMode.domains) {
        _addLog(
          LogEntry(
            level: LogLevel.debug,
            message: 'Installing rule sets...',
            time: DateTime.now(),
          ),
        );
        await installRuleSets(paths.working, _services);
        _addLog(
          LogEntry(
            level: LogLevel.info,
            message: 'Rule sets installed',
            time: DateTime.now(),
          ),
        );
      }

      final content = ConfigBuilder.build(
        config: config,
        services: _services,
        mode: _mode,
        workingPath: paths.working,
      );

      _addLog(
        LogEntry(
          level: LogLevel.debug,
          message: 'Validating config with sing-box...',
          time: DateTime.now(),
        ),
      );
      await client.checkConfig(content);
      _addLog(
        LogEntry(
          level: LogLevel.info,
          message: 'Config validation passed',
          time: DateTime.now(),
        ),
      );

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

      _addLog(
        LogEntry(
          level: LogLevel.info,
          message:
              'Starting VPN service (per-app: ${_mode == TunnelMode.apps}, packages: ${packages.join(", ")})',
          time: DateTime.now(),
        ),
      );

      await client.connect(
        SessionOptions(
          config: content,
          networkMode: NetworkMode.vpn,
          // Weak TV boxes have 1-2 GB of RAM: cap the Go heap and drop the
          // oldest connections instead of letting the process get OOM-killed.
          memoryLimit: const MemoryLimitConfig(
            enabled: true,
            limitMb: 128,
            killConnections: true,
          ),
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
      _addLog(
        LogEntry(
          level: LogLevel.info,
          message: 'VPN service started successfully',
          time: DateTime.now(),
        ),
      );
    } on VpnPermissionDenied catch (error) {
      _busy = false;
      _error = error.message;
      _addLog(
        LogEntry(
          level: LogLevel.error,
          message: 'VPN permission denied',
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    } on PlatformException catch (error) {
      _busy = false;
      _error = error.message ?? error.code;
      _addLog(
        LogEntry(
          level: LogLevel.error,
          message: 'Platform error: ${error.code} ${error.message}',
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    } catch (error) {
      _busy = false;
      _error = _humanize(error);
      _addLog(
        LogEntry(
          level: LogLevel.error,
          message: 'Connect error: $error',
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_busy || !_state.isRunning) return;
    _busy = true;
    _error = null;
    _addLog(
      LogEntry(
        level: LogLevel.info,
        message: '=== DISCONNECT ===',
        time: DateTime.now(),
      ),
    );
    notifyListeners();
    try {
      await client.disconnect();
      _addLog(
        LogEntry(
          level: LogLevel.info,
          message: 'VPN service stopped',
          time: DateTime.now(),
        ),
      );
    } catch (error) {
      _busy = false;
      _error = _humanize(error);
      _addLog(
        LogEntry(
          level: LogLevel.error,
          message: 'Disconnect error: $error',
          time: DateTime.now(),
        ),
      );
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
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
    _logSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

class VpnPermissionDenied implements Exception {
  const VpnPermissionDenied();

  String get message => 'Разрешение на VPN не выдано.';
}
