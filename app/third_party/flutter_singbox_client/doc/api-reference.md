# API Reference

## Lifecycle

| Method | Returns | Description |
|---|---|---|
| `initialize([EngineOptions])` | `Future<void>` | Initialize the engine. Call once at startup. Idempotent. |
| `dispose()` | `Future<void>` | Release SDK resources. |
| `requestVPNPermission()` | `Future<bool>` | Request Android VPN permission. Returns `true` if granted. |
| `connect(SessionOptions)` | `Future<void>` | Start the VPN or proxy service. |
| `disconnect()` | `Future<void>` | Stop the running service. |
| `reloadConfig()` | `Future<void>` | Hot-reload config without restarting the service. |
| `getServiceState()` | `Future<ServiceState>` | Point-in-time state snapshot. |
| `getVersion()` | `Future<String>` | Plugin version string. |
| `getCoreVersion()` | `Future<String>` | Sing-box core version (e.g. `'1.10.0'`). |

---

## Config

| Method | Returns | Description |
|---|---|---|
| `checkConfig(String)` | `Future<void>` | Validate config. **Throws** `PlatformException` with the Go core error on invalid input. |
| `formatConfig(String)` | `Future<String>` | Pretty-print a config JSON string. |

---

## Outbounds & Groups

| Method | Returns | Description |
|---|---|---|
| `selectOutbound(groupTag, outboundTag)` | `Future<void>` | Select an outbound in a proxy group. |
| `urlTest(groupTag)` | `Future<void>` | Run URL latency test for all outbounds in a group. |
| `setClashMode(String)` | `Future<void>` | Switch the active Clash mode. |

---

## Connections

| Method | Returns | Description |
|---|---|---|
| `closeConnection(String id)` | `Future<void>` | Close a specific connection by ID. |
| `closeAllConnections()` | `Future<void>` | Close all active connections. |

---

## Traffic & System Proxy

| Method | Returns | Description |
|---|---|---|
| `getTrafficStats()` | `Future<TrafficStats>` | Point-in-time traffic statistics snapshot. |
| `getSystemProxyStatus()` | `Future<SystemProxyStatus>` | Current availability and enabled state. |
| `setSystemProxyEnabled(bool)` | `Future<void>` | Toggle the system HTTP proxy at runtime. |

---

## Network Testing

| Method | Returns | Description |
|---|---|---|
| `startStunTest([server])` | `Future<void>` | Start STUN test. Results stream via `stunProgressStream`. |
| `stopStunTest()` | `Future<void>` | Cancel a running STUN test. |
| `startNetworkQualityTest()` | `Future<void>` | Start quality test. Results stream via `networkQualityProgressStream`. |
| `stopNetworkQualityTest()` | `Future<void>` | Cancel a running quality test. |

---

## Event Streams

All SDK events arrive as Dart broadcast streams. Subscribe once during initialization and hold subscriptions for the lifetime of your state object.

| Stream | Type | Emits | Description |
|---|---|---|---|
| `serviceStateStream` | `Stream<ServiceState>` | On change | Service lifecycle transitions |
| `trafficStatsStream` | `Stream<TrafficStats>` | ~1 Hz | Live upload/download rates and session totals |
| `coreLogStream` | `Stream<List<LogEntry>>` | On new logs | Verbose Go core logs — for debugging |
| `connectionStream` | `Stream<List<ConnectionInfo>>` | On change | Full connection list updates |
| `outboundGroupStream` | `Stream<List<OutboundGroup>>` | On change | Proxy group state (latency, selection) |
| `clashModeStream` | `Stream<String>` | On change | Currently active Clash mode |
| `clashModesStream` | `Stream<List<String>>` | On connect | Available Clash modes from the loaded config |
| `faultStream` | `Stream<String>` | On error | **Critical service failures — always surface to the user** |
| `networkQualityProgressStream` | `Stream<NetworkQualityProgress>` | During test | Network quality test progress |
| `stunProgressStream` | `Stream<StunProgress>` | During test | STUN test phase progress |

### `coreLogStream` vs `faultStream`

| | `coreLogStream` | `faultStream` |
|---|---|---|
| **Content** | Batched `LogEntry` objects from the Go engine | Plain error strings from the SDK layer |
| **Volume** | High — continuous during operation | Low — one emission per critical failure |
| **Use case** | Developer log viewer, diagnostics | User-facing error display |
| **Show to users?** | No — too verbose and technical | **Yes — always** |

> `faultStream` emits when the service cannot start or stops due to an error. Every emission means the VPN/proxy is not running. Surface every message as a snackbar, dialog, or status banner.
