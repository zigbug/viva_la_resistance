# Getting Started

## Initialization

Initialize the engine **once** at application startup, before calling any other method.

```dart
await client.initialize();
```

`initialize()` is idempotent — subsequent calls are no-ops.

### EngineOptions

`EngineOptions` allows overriding engine storage paths and the internal IPC port. **The defaults are correct for all standard deployments.**

```dart
await client.initialize(
  const EngineOptions(
    basePath: '/data/user/0/com.example.app/files/engine',
    workingPath: '/data/user/0/com.example.app/files/engine/working',
    tempPath: '/data/user/0/com.example.app/cache',
    commandServerPort: 10087,       // only if 10086 conflicts
    commandServerSecret: 'secret',  // optional IPC auth token
  ),
);
```

| Field | Default | Purpose |
|---|---|---|
| `basePath` | `<cacheDir>/flutter_singbox_client_engine` | Engine coordination and runtime files |
| `workingPath` | `<basePath>/working` | Geo rule sets, DNS cache, resolved config |
| `tempPath` | System temp dir | Scratch files during setup |
| `commandServerPort` | `10086` | Localhost IPC port between Kotlin and Go core |
| `commandServerSecret` | `''` | Optional auth token for IPC hardening |

> `commandServerPort` is strictly internal SDK IPC — it is unrelated to VPN/proxy ports or user traffic.

---

## Config Validation

Always validate configs before passing them to `connect()`. `checkConfig()` calls the Go core directly and returns the exact error message on failure.

```dart
try {
  await client.checkConfig(configJson);
} catch (e) {
  showError('$e'); // full Go core error message
  return;
}

// Optional: format/pretty-print before storing
final formatted = await client.formatConfig(configJson);
```

| Method | Returns | Description |
|---|---|---|
| `checkConfig(String)` | `Future<void>` | Validates via the Go core. **Throws** `PlatformException` with the full error on invalid input. |
| `formatConfig(String)` | `Future<String>` | Pretty-prints the JSON. |

---

## Service Lifecycle

### Starting

```dart
await client.connect(SessionOptions(
  config: configJson,           // required — Sing-box JSON config string
  networkMode: NetworkMode.vpn, // default: vpn
  allowBypass: false,           // VPN mode only
  systemProxyEnabled: false,    // VPN mode, Android Q+ only
  killSwitch: false,            // VPN mode, API 26+ only
  perAppProxy: null,            // VPN mode only
  memoryLimit: null,            // Go runtime memory cap
  notification: NotificationConfig(
    title: 'VPN Active',
    showTrafficStats: true,
    showStopButton: true,
    stopButtonLabel: 'Disconnect',
  ),
));
```

### Stopping

```dart
await client.disconnect();
```

### Hot Reload

Reloads config without tearing down the service. Existing connections are preserved.

```dart
await client.reloadConfig();
```

### Checking State

```dart
final state = await client.getServiceState();
if (state.isRunning) { ... }
if (state.isIdle) { ... }
```

Or subscribe to the stream for continuous updates:

```dart
client.serviceStateStream.listen((state) {
  setState(() => _serviceState = state);
});
```

---

## SessionOptions

`SessionOptions` is the self-contained start descriptor. Nothing is read from storage at start time — supply everything on every call.

| Field | Required | Default | Description |
|---|---|---|---|
| `config` | ✅ | — | Sing-box JSON config string. Validate with `checkConfig()` first. |
| `networkMode` | | `vpn` | `vpn` for TUN tunnel; `proxy` for HTTP/SOCKS only. |
| `allowBypass` | | `false` | VPN mode only. Allow apps to opt out of the tunnel. Suppressed when `killSwitch: true`. |
| `systemProxyEnabled` | | `false` | VPN mode, Android Q+ only. Register the HTTP inbound as system-wide proxy. |
| `killSwitch` | | `false` | VPN mode, API 26+ only. Block all traffic when the tunnel is down. |
| `perAppProxy` | | `null` | Per-app routing filter. `null` = all apps routed normally. |
| `memoryLimit` | | `null` | Go runtime soft memory cap. `null` = no cap. |
| `notification` | | SDK defaults | Foreground notification appearance. |

**VPN with per-app exclusion:**

```dart
await client.connect(SessionOptions(
  config: configJson,
  networkMode: NetworkMode.vpn,
  killSwitch: true,
  perAppProxy: PerAppProxyOptions(
    mode: PerAppProxyMode.exclude,
    packages: ['com.mycompany.internalapp'],
  ),
  notification: NotificationConfig(title: 'VPN Active', showTrafficStats: true),
));
```

**Proxy mode:**

```dart
await client.connect(SessionOptions(
  config: proxyOnlyConfigJson, // must not contain a tun inbound
  networkMode: NetworkMode.proxy,
  notification: NotificationConfig(title: 'Proxy Active'),
));
```

**With memory limit:**

```dart
await client.connect(SessionOptions(
  config: configJson,
  memoryLimit: MemoryLimitConfig(enabled: true, limitMb: 150),
));
```

---

## NotificationConfig

Controls the foreground service notification.

| Field | Default | Description |
|---|---|---|
| `title` | `'Singbox'` | Notification title |
| `channelName` | `'VPN Service'` | Android notification channel name (visible in system Settings) |
| `showTrafficStats` | `false` | Show live upload/download speeds in the notification body |
| `showStopButton` | `false` | Add a stop/disconnect action button |
| `stopButtonLabel` | `'Stop'` | Label for the stop button |

> Notification settings take effect when the service starts. Changes do not apply to a running service until the next `connect()`.

---

## Traffic Statistics

```dart
// Live stream (~1 Hz while the service is running)
client.trafficStatsStream.listen((stats) {
  setState(() => _stats = stats);
});

// Point-in-time snapshot
final stats = await client.getTrafficStats();
print('↑ ${stats.uplinkBps} bps  ↓ ${stats.downlinkBps} bps');
```

Use `TrafficStats.zero` as a safe initial/default value before the first event arrives. See [Data Models](models.md#trafficstats) for the full field reference.

---

## Outbound Groups

Subscribe to `outboundGroupStream` to observe proxy group state. It emits once on connect and again on every change (latency update, selection change).

```dart
client.outboundGroupStream.listen((groups) {
  setState(() => _groups = groups);
});

// Run a URL latency test for all outbounds in a group
await client.urlTest(group.tag);

// Select a specific outbound (selector groups only)
await client.selectOutbound(group.tag, 'HK-01');
```

Only groups where `selectable == true` support `selectOutbound()`. See [Data Models](models.md#outboundgroup) for the full field reference.

---

## Clash Mode

Clash Mode only works if your config defines a `clash_api` block with named modes.

```dart
// Available modes — emitted once on connect
client.clashModesStream.listen((modes) {
  setState(() => _availableModes = modes); // e.g. ['direct', 'global', 'rule']
});

// Active mode — emitted on connect and on every change
client.clashModeStream.listen((mode) {
  setState(() => _currentMode = mode);
});

// Switch mode
await client.setClashMode('global');
```

---

## Connections

```dart
// Full connection list — emitted on every open/close event
client.connectionStream.listen((connections) {
  setState(() => _connections = connections);
});

// Filter for active connections only
final active = connections.where((c) => c.isActive).toList();

// Close individual connections
await client.closeConnection(connection.id);
await client.closeAllConnections();
```

See [Data Models](models.md#connectioninfo) for the full `ConnectionInfo` field reference.

---

## System Proxy

Registers the Sing-box HTTP inbound as the device-wide HTTP proxy via `VpnService.Builder.setHttpProxy()`.

> **VPN mode only.** Requires Android 10+ (API 29+) and an HTTP inbound in your config. `getSystemProxyStatus()` returns `available: false` in all other cases.

```dart
// Enable at startup
await client.connect(SessionOptions(config: configJson, systemProxyEnabled: true));

// Check status at runtime
final status = await client.getSystemProxyStatus();
// status.available — false if proxy mode, API < 29, or no HTTP inbound
// status.enabled   — true if currently active

// Toggle at runtime (no restart required)
await client.setSystemProxyEnabled(true);
await client.setSystemProxyEnabled(false);
```

---

## Network Testing

### STUN Test

Tests external IP, latency, NAT mapping, and NAT filtering in three sequential phases.

```dart
StreamSubscription<StunProgress>? _sub;

_sub = client.stunProgressStream.listen((p) {
  setState(() => _progress = p);
  if (!p.isRunning) _sub = null; // test complete
});

await client.startStunTest();                        // uses libbox default server
await client.startStunTest('stun.example.com:3478'); // custom server
await client.stopStunTest();                         // cancel early
```

Always cancel the subscription and call `stopStunTest()` in your widget's `dispose()` if the user navigates away mid-test.

### Network Quality Test

Runs for up to 30 seconds, emitting live progress updates throughout.

```dart
StreamSubscription<NetworkQualityProgress>? _sub;

_sub = client.networkQualityProgressStream.listen((p) {
  setState(() => _progress = p);
  if (!p.isRunning) _sub = null; // test complete
});

await client.startNetworkQualityTest();
await client.stopNetworkQualityTest(); // cancel early
```

See [Data Models](models.md#stunprogress) and [Data Models](models.md#networkqualityprogress) for field references.

---

## Remote Profile URLs

The SDK does not fetch URLs. `SessionOptions.config` requires a fully-resolved JSON string. Fetching, caching, and refresh scheduling are your application's responsibility.

```dart
// Minimal fetch-and-connect pattern
final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
await client.checkConfig(response.body); // throws on invalid
await client.connect(SessionOptions(config: response.body));
```

This keeps the SDK free of HTTP client logic, leaving your app in full control of credential handling, cache policy, and retry behaviour.

---

## Boot Auto-start

The SDK's `BootReceiver` relays `dev.amirzr.singbox.DEVICE_BOOTED` to your app after device boot. Register your own receiver to restart the service using your persisted state:

```kotlin
class BootRestartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != "dev.amirzr.singbox.DEVICE_BOOTED") return
        // Read your persisted "was running" flag and re-launch
    }
}
```

```xml
<receiver android:name=".BootRestartReceiver" android:exported="false">
    <intent-filter>
        <action android:name="dev.amirzr.singbox.DEVICE_BOOTED" />
    </intent-filter>
</receiver>
```
