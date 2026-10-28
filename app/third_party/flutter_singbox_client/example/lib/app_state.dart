import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/app_profile.dart';
import 'services/preferences_service.dart';
import 'services/profile_service.dart';

class AppState extends ChangeNotifier {
  final _client = SingboxClient();
  SingboxClient get client => _client;

  // ── Services (initialized in initialize()) ────────────────────────────
  late PreferencesService _prefs;
  late ProfileService _profileService;

  // ── Connection state ──────────────────────────────────────────────────
  ServiceState serviceState = ServiceState.stopped;
  TrafficStats trafficStats = TrafficStats.zero;

  // ── Profiles ──────────────────────────────────────────────────────────
  List<AppProfile> profiles = [];
  int? selectedProfileId;

  // ── Outbound groups ───────────────────────────────────────────────────
  List<OutboundGroup> groups = [];
  List<String> clashModes = [];
  String currentClashMode = '';

  // ── Connections ───────────────────────────────────────────────────────
  List<ConnectionInfo> connections = [];

  // ── Logs ──────────────────────────────────────────────────────────────
  final List<LogEntry> logs = [];
  final List<LogEntry> faultEntries = [];
  static const _maxLogs = 1000;

  // ── Alerts ───────────────────────────────────────────────────────────
  final List<String> alerts = [];
  static const _maxAlerts = 200;
  String? lastAlert;

  // ── Core version ─────────────────────────────────────────────────────
  String coreVersion = '';

  // ── Settings (persisted via PreferencesService) ───────────────────────
  NetworkMode get networkMode => NetworkMode.fromString(_prefs.networkMode);
  set networkMode(NetworkMode v) {
    _prefs.networkMode = v.toValue();
    notifyListeners();
  }

  bool get allowBypass => _prefs.allowBypass;
  set allowBypass(bool v) {
    _prefs.allowBypass = v;
    notifyListeners();
  }

  bool get systemProxyEnabled => _prefs.systemProxyEnabled;
  set systemProxyEnabled(bool v) {
    _prefs.systemProxyEnabled = v;
    notifyListeners();
  }

  // ── Notification config ───────────────────────────────────────────────
  String get notificationTitle => _prefs.notificationTitle;
  set notificationTitle(String v) {
    _prefs.notificationTitle = v;
    notifyListeners();
  }

  String get notificationChannelName => _prefs.notificationChannelName;
  set notificationChannelName(String v) {
    _prefs.notificationChannelName = v;
    notifyListeners();
  }

  bool get showTrafficInNotification => _prefs.showTrafficInNotification;
  set showTrafficInNotification(bool v) {
    _prefs.showTrafficInNotification = v;
    notifyListeners();
  }

  bool get showStopButtonInNotification => _prefs.showStopButtonInNotification;
  set showStopButtonInNotification(bool v) {
    _prefs.showStopButtonInNotification = v;
    notifyListeners();
  }

  // ── Memory limit ──────────────────────────────────────────────────────
  bool get enableMemoryLimit => _prefs.enableMemoryLimit;
  set enableMemoryLimit(bool v) {
    _prefs.enableMemoryLimit = v;
    notifyListeners();
  }

  int get memoryLimitMb => _prefs.memoryLimitMb;
  set memoryLimitMb(int v) {
    _prefs.memoryLimitMb = v;
    notifyListeners();
  }

  bool get killConnectionsOnLimit => _prefs.killConnectionsOnLimit;
  set killConnectionsOnLimit(bool v) {
    _prefs.killConnectionsOnLimit = v;
    notifyListeners();
  }

  bool get killSwitch => _prefs.killSwitch;
  set killSwitch(bool v) {
    _prefs.killSwitch = v;
    notifyListeners();
  }

  // ── Per-app proxy ─────────────────────────────────────────────────────
  bool get perAppProxyEnabled => _prefs.perAppProxyEnabled;
  set perAppProxyEnabled(bool v) {
    _prefs.perAppProxyEnabled = v;
    notifyListeners();
  }

  PerAppProxyMode get perAppProxyMode =>
      _prefs.perAppProxyMode == 'include'
          ? PerAppProxyMode.include
          : PerAppProxyMode.exclude;
  set perAppProxyMode(PerAppProxyMode v) {
    _prefs.perAppProxyMode = v.name;
    notifyListeners();
  }

  Set<String> get perAppProxyPackages =>
      _prefs.perAppProxyPackages.toSet();
  set perAppProxyPackages(Set<String> v) {
    _prefs.perAppProxyPackages = v.toList();
    notifyListeners();
  }

  void togglePerAppPackage(String package) {
    final current = perAppProxyPackages;
    if (current.contains(package)) {
      current.remove(package);
    } else {
      current.add(package);
    }
    perAppProxyPackages = current;
  }

  // ── Config validation state ───────────────────────────────────────────
  String? configValidationError;
  bool isValidatingConfig = false;

  // ── Init ──────────────────────────────────────────────────────────────
  bool initialized = false;
  bool initializing = false;
  String? initError;

  final List<StreamSubscription> _subs = [];

  Future<void> initialize() async {
    if (initialized || initializing) return;
    initializing = true;
    initError = null;
    notifyListeners();

    try {
      _prefs = await PreferencesService.create();
      _profileService = await ProfileService.create(_client);

      await _client.initialize(const EngineOptions());
      coreVersion = await _client.getCoreVersion();

      _subs.add(_client.serviceStateStream.listen((s) {
        serviceState = s;
        if (!s.isRunning) _clearRuntimeState();
        notifyListeners();
      }));

      _subs.add(_client.trafficStatsStream.listen((t) {
        trafficStats = t;
        notifyListeners();
      }));

      _subs.add(_client.coreLogStream.listen((entries) {
        logs.addAll(entries);
        while (logs.length > _maxLogs) {
          logs.removeAt(0);
        }
        notifyListeners();
      }));

      _subs.add(_client.connectionStream.listen((events) {
        final map = {for (final c in connections) c.id: c};
        for (final ev in events) {
          final existing = map[ev.id];
          if (existing != null && ev.closedAt != null) {
            map[ev.id] = existing.copyWith(
              closedAt: ev.closedAt,
              uplinkTotalBytes: ev.uplinkTotalBytes > 0 ? ev.uplinkTotalBytes : null,
              downlinkTotalBytes: ev.downlinkTotalBytes > 0 ? ev.downlinkTotalBytes : null,
            );
          } else {
            map[ev.id] = ev;
          }
        }
        connections = map.values.toList();
        notifyListeners();
      }));

      _subs.add(_client.outboundGroupStream.listen((g) {
        groups = g;
        notifyListeners();
      }));

      _subs.add(_client.clashModeStream.listen((mode) {
        currentClashMode = mode;
        notifyListeners();
      }));

      _subs.add(_client.clashModesStream.listen((modes) {
        clashModes = modes;
        notifyListeners();
      }));

      _subs.add(_client.faultStream.listen((msg) {
        lastAlert = msg;
        alerts.add(msg);
        while (alerts.length > _maxAlerts) {
          alerts.removeAt(0);
        }
        faultEntries.add(LogEntry(
          level: LogLevel.fatal,
          message: msg,
          time: DateTime.now(),
        ));
        while (faultEntries.length > _maxLogs) {
          faultEntries.removeAt(0);
        }
        notifyListeners();
      }));

      profiles = _profileService.list();
      selectedProfileId = _prefs.selectedProfileId;

      initialized = true;
    } catch (e) {
      initError = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestRequiredPermissions() async {
    bool vpnGranted;
    try {
      vpnGranted = await _client.requestVPNPermission();
    } catch (e) {
      lastAlert = _extractMessage(e);
      notifyListeners();
      return false;
    }
    if (!vpnGranted) {
      lastAlert = 'VPN permission required to use the service';
      notifyListeners();
      return false;
    }
    final notifGranted = await _requestNotificationPermission();
    if (!notifGranted) {
      lastAlert = 'Notification permission required for service notifications';
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> toggleService() async {
    if (serviceState.isRunning) {
      try {
        await _client.disconnect();
      } catch (e) {
        lastAlert = _extractMessage(e);
        notifyListeners();
      }
    } else if (serviceState.isIdle) {
      final permissionsGranted = await _requestRequiredPermissions();
      if (!permissionsGranted) return;

      final profileId = selectedProfileId;
      if (profileId == null) {
        lastAlert = 'Please select a profile first';
        notifyListeners();
        return;
      }

      final content = _profileService.getContent(profileId);
      if (content == null || content.isEmpty) {
        lastAlert = 'Selected profile has no content';
        notifyListeners();
        return;
      }

      final packages = perAppProxyPackages;
      try {
        await _client.connect(SessionOptions(
          config: content,
          networkMode: networkMode,
          allowBypass: allowBypass,
          systemProxyEnabled: systemProxyEnabled,
          killSwitch: killSwitch && networkMode == NetworkMode.vpn,
          perAppProxy: perAppProxyEnabled && packages.isNotEmpty
              ? PerAppProxyOptions(
                  mode: perAppProxyMode,
                  packages: packages.toList(),
                )
              : null,
          memoryLimit: enableMemoryLimit
              ? MemoryLimitConfig(
                  enabled: true,
                  limitMb: memoryLimitMb,
                  killConnections: killConnectionsOnLimit,
                )
              : null,
          notification: NotificationConfig(
            title: notificationTitle,
            channelName: notificationChannelName,
            showTrafficStats: showTrafficInNotification,
            showStopButton: showStopButtonInNotification,
            stopButtonLabel: 'STOP',
          ),
        ));
      } catch (_) {
        // Real error already delivered via faultStream; swallow the generic exception.
      }
    }
  }

  String _extractMessage(Object e) {
    final dynamic ex = e;
    try {
      final msg = ex.message as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return e.toString();
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      lastAlert = _extractMessage(e);
      notifyListeners();
    }
  }

  void selectProfile(int id) {
    selectedProfileId = id;
    _prefs.selectedProfileId = id;
    notifyListeners();
  }

  Future<String> formatConfig(String content) async {
    return _client.formatConfig(content);
  }

  Future<void> addLocalProfile(String name, String content) async {
    try {
      isValidatingConfig = true;
      configValidationError = null;
      notifyListeners();

      await _client.checkConfig(content);

      final formatted = await _client.formatConfig(content);
      await _profileService.add(
        name: name,
        type: AppProfileType.local,
        content: formatted,
      );
      profiles = _profileService.list();
      configValidationError = null;
    } catch (e) {
      configValidationError = _extractMessage(e);
    } finally {
      isValidatingConfig = false;
      notifyListeners();
    }
  }

  Future<void> addRemoteProfile(
    String name,
    String url, {
    bool autoUpdate = false,
    int autoUpdateIntervalSeconds = 3600,
  }) async {
    try {
      isValidatingConfig = true;
      configValidationError = null;
      notifyListeners();

      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        configValidationError = 'Invalid URL: must start with http:// or https://';
        notifyListeners();
        return;
      }

      await _profileService.add(
        name: name,
        type: AppProfileType.remote,
        remoteURL: url,
        autoUpdate: autoUpdate,
        autoUpdateIntervalSeconds: autoUpdateIntervalSeconds,
      );
      profiles = _profileService.list();
      configValidationError = null;
    } catch (e) {
      configValidationError = 'Remote profile error: $e';
    } finally {
      isValidatingConfig = false;
      notifyListeners();
    }
  }

  Future<void> editLocalProfile(int id, String name, String content) async {
    try {
      isValidatingConfig = true;
      configValidationError = null;
      notifyListeners();

      await _client.checkConfig(content);

      final formatted = await _client.formatConfig(content);
      await _profileService.updateLocal(id, name: name, content: formatted);
      profiles = _profileService.list();
      configValidationError = null;
    } catch (e) {
      configValidationError = _extractMessage(e);
    } finally {
      isValidatingConfig = false;
      notifyListeners();
    }
  }

  Future<void> editRemoteProfile(
    int id,
    String name,
    String url, {
    bool autoUpdate = false,
    int autoUpdateIntervalSeconds = 3600,
  }) async {
    try {
      isValidatingConfig = true;
      configValidationError = null;
      notifyListeners();

      final uri = Uri.tryParse(url);
      if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
        configValidationError = 'Invalid URL: must start with http:// or https://';
        notifyListeners();
        return;
      }

      await _profileService.updateRemote(id,
          name: name,
          url: url,
          autoUpdate: autoUpdate,
          autoUpdateIntervalSeconds: autoUpdateIntervalSeconds);
      profiles = _profileService.list();
      configValidationError = null;
    } catch (e) {
      configValidationError = 'Edit error: $e';
    } finally {
      isValidatingConfig = false;
      notifyListeners();
    }
  }

  Future<void> deleteProfile(int id) async {
    _profileService.delete(id);
    if (selectedProfileId == id) {
      selectedProfileId = null;
      _prefs.selectedProfileId = null;
    }
    profiles = _profileService.list();
    notifyListeners();
  }

  Future<void> updateRemoteProfile(int id) => _guard(() async {
    await _profileService.fetchAndUpdate(id);
    profiles = _profileService.list();
    notifyListeners();
  });

  Future<void> selectOutbound(String groupTag, String outboundTag) =>
      _guard(() => _client.selectOutbound(groupTag, outboundTag));

  Future<void> urlTest(String groupTag) =>
      _guard(() => _client.urlTest(groupTag));

  Future<void> setClashMode(String mode) =>
      _guard(() => _client.setClashMode(mode));

  Future<void> closeConnection(String id) =>
      _guard(() => _client.closeConnection(id));

  Future<void> closeAllConnections() =>
      _guard(() => _client.closeAllConnections());

  Future<void> reloadConfig() => _guard(() => _client.reloadConfig());


  void clearAlert() {
    lastAlert = null;
    notifyListeners();
  }

  void clearAlerts() {
    alerts.clear();
    lastAlert = null;
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    notifyListeners();
  }

  void clearFaults() {
    faultEntries.clear();
    alerts.clear();
    lastAlert = null;
    notifyListeners();
  }

  void _clearRuntimeState() {
    trafficStats = TrafficStats.zero;
    connections = [];
    groups = [];
    clashModes = [];
    currentClashMode = '';
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
