# Best Practices

## Always validate before connecting

`checkConfig()` calls the Go core and returns the exact error on failure. Run it before every `connect()` — not just when a profile is first added.

```dart
try {
  await client.checkConfig(configJson);
} catch (e) {
  showError('$e');
  return;
}
await client.connect(SessionOptions(config: configJson));
```

---

## Always subscribe to `faultStream`

```dart
client.faultStream.listen((msg) => showSnackbar(msg));
```

Every `faultStream` emission means the service is not running. Not subscribing means the user sees a silent failure with no explanation. Subscribe before calling `connect()`, not after.

---

## Rebuild `SessionOptions` from your own state on every connect

The SDK has no memory of previous runs. Every `connect()` call must be self-contained.

```dart
final profile = await profileRepo.getSelected();
final settings = await settingsRepo.load();

await client.connect(SessionOptions(
  config: profile.content,
  networkMode: settings.networkMode,
  allowBypass: settings.allowBypass,
  killSwitch: settings.killSwitch && settings.networkMode == NetworkMode.vpn,
  notification: NotificationConfig(
    title: settings.notificationTitle,
    showTrafficStats: settings.showTrafficInNotification,
    showStopButton: true,
    stopButtonLabel: 'Disconnect',
  ),
));
```

---

## Check service state before connecting

```dart
final state = await client.getServiceState();
if (!state.isIdle) return; // already running or transitioning
```

Or use `serviceStateStream` to drive your UI connect button:

```dart
client.serviceStateStream.listen((state) {
  setState(() {
    _canConnect = state.isIdle;
    _canDisconnect = state.isRunning;
  });
});
```

---

## Cap in-memory log buffers

`coreLogStream` is high-volume — continuous during operation. Without a cap, logs accumulate unboundedly.

```dart
client.coreLogStream.listen((entries) {
  logs.addAll(entries);
  if (logs.length > 1000) logs.removeRange(0, logs.length - 1000);
});
```

---

## Cancel stream subscriptions on dispose

Hold all subscriptions and cancel them when your state object is disposed.

```dart
final List<StreamSubscription> _subs = [];

// In initialize():
_subs.add(client.serviceStateStream.listen(...));
_subs.add(client.trafficStatsStream.listen(...));
// etc.

// In dispose():
for (final sub in _subs) sub.cancel();
```

---

## Cancel test subscriptions on page dispose

STUN and network quality tests run on independent subscriptions. Cancel them if the user navigates away.

```dart
StreamSubscription<StunProgress>? _stunSub;

@override
void dispose() {
  _stunSub?.cancel();
  client.stopStunTest(); // cancel the test itself
  super.dispose();
}
```

---

## Request `POST_NOTIFICATIONS` before connecting on Android 13+

The SDK declares the permission but cannot request it on your behalf. Without it, the foreground notification is silently suppressed.

```dart
await Permission.notification.request(); // using permission_handler
```

---

## One service at a time

Only one VPN or proxy service can run at a time. Calling `connect()` while the service is already running has no effect. Always `disconnect()` first when switching configs or modes.

```dart
if (serviceState.isRunning) {
  await client.disconnect();
}
await client.connect(SessionOptions(config: newConfig));
```

---

## Integration Example

A minimal but complete `ChangeNotifier` that integrates the SDK into a Flutter app:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

class VpnProfile {
  final String name;
  final String content; // validated Sing-box JSON
  VpnProfile({required this.name, required this.content});
}

/// Application state — owns all persistence and settings.
/// The SDK owns nothing.
class VpnState extends ChangeNotifier {
  final _client = SingboxClient();
  final List<StreamSubscription> _subs = [];

  // App-owned state
  final List<VpnProfile> profiles = [];
  VpnProfile? selectedProfile;
  NetworkMode networkMode = NetworkMode.vpn;

  // SDK-emitted state
  ServiceState serviceState = ServiceState.stopped;
  TrafficStats trafficStats = TrafficStats.zero;
  List<OutboundGroup> groups = [];
  List<ConnectionInfo> connections = [];
  List<LogEntry> logs = [];
  List<String> clashModes = [];
  String currentClashMode = '';
  String? lastFault;

  Future<void> initialize() async {
    await _client.initialize(const EngineOptions());

    _subs.addAll([
      _client.serviceStateStream.listen((s)  { serviceState = s;     notifyListeners(); }),
      _client.trafficStatsStream.listen((s)  { trafficStats = s;     notifyListeners(); }),
      _client.connectionStream.listen((c)    { connections = c;      notifyListeners(); }),
      _client.outboundGroupStream.listen((g) { groups = g;           notifyListeners(); }),
      _client.clashModesStream.listen((m)    { clashModes = m;       notifyListeners(); }),
      _client.clashModeStream.listen((m)     { currentClashMode = m; notifyListeners(); }),
      _client.faultStream.listen((msg)       { lastFault = msg;      notifyListeners(); }),
      _client.coreLogStream.listen((entries) {
        logs.addAll(entries);
        if (logs.length > 1000) logs.removeRange(0, logs.length - 1000);
        notifyListeners();
      }),
    ]);
  }

  Future<void> addProfile(String name, String rawJson) async {
    await _client.checkConfig(rawJson); // throws with Go core error on invalid
    final formatted = await _client.formatConfig(rawJson);
    profiles.add(VpnProfile(name: name, content: formatted));
    notifyListeners();
  }

  Future<void> connect() async {
    final profile = selectedProfile;
    if (profile == null) throw Exception('No profile selected');
    if (!await _client.requestVPNPermission()) throw Exception('VPN permission denied');

    await _client.connect(SessionOptions(
      config: profile.content,
      networkMode: networkMode,
      notification: NotificationConfig(
        title: profile.name,
        showTrafficStats: true,
        showStopButton: true,
        stopButtonLabel: 'Disconnect',
      ),
    ));
  }

  Future<void> disconnect() => _client.disconnect();
  Future<void> setClashMode(String mode) => _client.setClashMode(mode);
  Future<void> selectOutbound(String group, String outbound) =>
      _client.selectOutbound(group, outbound);

  @override
  void dispose() {
    for (final sub in _subs) sub.cancel();
    _client.dispose();
    super.dispose();
  }
}
```
