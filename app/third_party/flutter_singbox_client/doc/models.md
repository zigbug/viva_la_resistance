# Data Models

## ServiceState

```dart
enum ServiceState { stopped, starting, started, stopping }
```

| Value | Description |
|---|---|
| `stopped` | Not running |
| `starting` | Starting up |
| `started` | Running and fully connected |
| `stopping` | Shutting down |

**Convenience properties:**

| Property | Description |
|---|---|
| `isRunning` | `true` when `started` |
| `isIdle` | `true` when `stopped` — safe to call `connect()` |
| `isTransitioning` | `true` when `starting` or `stopping` |

---

## NetworkMode

```dart
enum NetworkMode { vpn, proxy }
```

| Value | Description |
|---|---|
| `vpn` | Full device-wide TUN tunnel via `VpnService`. Requires VPN permission. |
| `proxy` | HTTP/SOCKS proxy via a plain foreground service. No TUN device, no permission required. |

See the [VPN Mode vs Proxy Mode](../README.md#vpn-mode-vs-proxy-mode) comparison table in the README.

---

## TrafficStats

| Field | Type | Description |
|---|---|---|
| `uplinkBps` | `int` | Current upload speed (bits/s) |
| `downlinkBps` | `int` | Current download speed (bits/s) |
| `uplinkTotalBytes` | `int` | Total bytes uploaded since service start |
| `downlinkTotalBytes` | `int` | Total bytes downloaded since service start |
| `memoryBytes` | `int` | Go runtime heap in use (bytes) |
| `goroutines` | `int` | Active Go goroutines |
| `connectionsIn` | `int` | Active inbound connections |
| `connectionsOut` | `int` | Active outbound connections |

> Use `TrafficStats.zero` as a safe initial/default value before the first stream event arrives.

---

## ConnectionInfo

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique connection ID |
| `inbound` | `String` | Inbound tag from config |
| `inboundType` | `String` | Inbound protocol type |
| `ipVersion` | `int` | `4` or `6` |
| `network` | `String` | `'tcp'` or `'udp'` |
| `source` | `String` | Source address (`IP:port`) |
| `destination` | `String` | Destination address (`IP:port`) |
| `domain` | `String` | Resolved domain name |
| `protocol` | `String` | Application protocol |
| `user` | `String` | Authenticated user (if applicable) |
| `outbound` | `String` | Outbound tag used |
| `outboundType` | `String` | Outbound protocol type |
| `rule` | `String` | Route rule that matched |
| `chain` | `String` | Outbound detour chain |
| `createdAt` | `DateTime` | Connection open time |
| `closedAt` | `DateTime?` | Close time; `null` if still active |
| `uplinkTotalBytes` | `int` | Total bytes uploaded |
| `downlinkTotalBytes` | `int` | Total bytes downloaded |
| `isActive` | `bool` | `true` when `closedAt == null` |
| `packageName` | `String?` | Originating Android package (per-app proxy only) |
| `processPath` | `String?` | Originating process path (desktop platforms) |

---

## OutboundGroup

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | Group name from config |
| `type` | `String` | `'selector'` or `'urltest'` |
| `selected` | `String` | Currently active outbound tag |
| `selectable` | `bool` | `true` for selector groups — only these support `selectOutbound()` |
| `isExpand` | `bool` | UI expand state from the core |
| `items` | `List<OutboundGroupItem>` | All outbounds in the group |

### OutboundGroupItem

| Field | Type | Description |
|---|---|---|
| `tag` | `String` | Outbound name |
| `type` | `String` | Outbound protocol type |
| `urlTestDelayMs` | `int` | Last measured latency (ms); `0` if never tested |
| `hasLatency` | `bool` | `true` when `urlTestDelayMs > 0` |
| `urlTestTime` | `DateTime?` | Timestamp of last URL test |

---

## LogEntry / LogLevel

```dart
enum LogLevel { trace, debug, info, warn, error, fatal, panic }
```

| Field | Type | Description |
|---|---|---|
| `level` | `LogLevel` | Severity |
| `message` | `String` | Log message |
| `time` | `DateTime` | Timestamp |

`LogEntry.toString()` → `[INFO] started`

---

## PerAppProxyOptions

```dart
PerAppProxyOptions({
  PerAppProxyMode mode = PerAppProxyMode.exclude,
  List<String> packages = const [],
})
```

| `mode` | Behaviour |
|---|---|
| `PerAppProxyMode.exclude` | All apps use the tunnel **except** the listed packages |
| `PerAppProxyMode.include` | Only the listed packages use the tunnel |

```dart
// Exclude one app from the tunnel
PerAppProxyOptions(
  mode: PerAppProxyMode.exclude,
  packages: ['com.mycompany.internalapp'],
)

// Route only specific apps through the VPN
PerAppProxyOptions(
  mode: PerAppProxyMode.include,
  packages: ['org.telegram.messenger', 'com.android.chrome'],
)
```

> To enumerate all installed apps for a split-tunneling UI, your host app needs `QUERY_ALL_PACKAGES` (requires a Google Play Permissions Declaration). The SDK itself does not enumerate packages. See [Android Permissions](android-permissions.md).

---

## MemoryLimitConfig

```dart
MemoryLimitConfig({
  bool enabled = false,
  int limitMb = 50,
  bool killConnections = false,
})
```

| Field | Description |
|---|---|
| `enabled` | Enable the Go runtime memory cap |
| `limitMb` | Soft memory limit in megabytes (`GOMEMLIMIT`) |
| `killConnections` | When `true`, drops active connections when the limit is hit to free memory faster |

**Recommended values by device RAM:**

| `limitMb` | Device RAM |
|---|---|
| 50 – 100 MB | Low (≤ 2 GB) |
| 100 – 200 MB | Mid (3 – 4 GB) |
| 200 – 500 MB | High (≥ 6 GB) |

> Memory limit changes require a full disconnect/reconnect to take effect.

---

## SystemProxyStatus

| Field | Type | Description |
|---|---|---|
| `available` | `bool` | `false` if proxy mode, API < 29, or no HTTP inbound in config |
| `enabled` | `bool` | `true` if the system proxy is currently active |

---

## StunProgress

| Field | Type | Description |
|---|---|---|
| `isRunning` | `bool` | `false` on final result |
| `phase` | `StunPhase` | `binding` → `natMapping` → `natFiltering` → `done` |
| `externalAddress` | `String` | Public IP:port |
| `latencyMs` | `int` | Round-trip to STUN server (ms) |
| `natMapping` | `String` | NAT mapping description |
| `natFiltering` | `String` | NAT filtering description |
| `natTypeSupported` | `bool` | `false` if NAT type could not be determined |

---

## NetworkQualityProgress

| Field | Type | Description |
|---|---|---|
| `isRunning` | `bool` | `false` on final result |
| `downloadCapacityBps` | `int` | Measured download throughput (bits/s) |
| `uploadCapacityBps` | `int` | Measured upload throughput (bits/s) |
| `idleLatencyMs` | `int` | Baseline latency with no competing traffic (ms) |
| `downloadRPM` | `int` | Download requests per minute |
| `uploadRPM` | `int` | Upload requests per minute |
