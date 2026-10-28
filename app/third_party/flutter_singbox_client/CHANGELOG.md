# Changelog

## 1.1.0 — 2026-07-24

- Document premium platform availability: **iOS**, **Windows**, **macOS**, and **Linux** (Sing-box 1.14.0-alpha.45)
- Improve README SEO for cross-platform discovery (Android free; iOS App Store safe; desktop builds)
- Update package description for pub.dev

## 1.0.1 — 2026-05-12

- Add dartdoc comments to all public API elements
- Fix `dart analyze` warnings: unused parameter, unused variable, missing braces, missing `const`, deprecated `RadioListTile` usage, unnecessary string interpolation
- Fix pub.dev issues: rename `LICENSE.md` → `LICENSE`, rename `docs/` → `doc/`, add `license`, `repository`, and `issue_tracker` fields to `pubspec.yaml`
- Fix screenshot URLs in README to use absolute raw GitHub paths (visible on pub.dev)

## 1.0.0 — 2026-05-12

Initial release.

### Features

- **VPN Mode** — Full device-wide TUN tunnel via Android `VpnService` with automatic route management
- **Proxy Mode** — HTTP/SOCKS proxy without a TUN device, no VPN permission required
- **Config Validation** — Go core validation and JSON formatting via `checkConfig()` and `formatConfig()`
- **Hot Reload** — Reload config without restarting the service or dropping existing connections
- **Kill Switch** — Block all traffic at the OS level when the tunnel is down (API 26+)
- **Per-App Proxy** — Include or exclude specific apps from the tunnel (split tunneling, VPN mode only)
- **System Proxy** — Register HTTP inbound as device-wide proxy on Android Q+ (API 29+)
- **Live Traffic Stats** — Real-time upload/download speeds and session totals at ~1 Hz
- **Connection Tracking** — Full per-connection metadata, lifecycle events, and close control
- **Outbound Groups** — Live outbound group state with URL latency testing and manual selection
- **Clash API** — Runtime mode switching and outbound group control
- **Live Logs** — Real-time Go core log streaming with per-level filtering
- **Fault Alerts** — Dedicated fault stream for actionable service errors
- **Memory Limits** — Go runtime soft memory cap (`GOMEMLIMIT`) with optional connection kill
- **STUN Test** — NAT type detection, external IP, and latency measurement in three sequential phases
- **Network Quality Test** — Download/upload speed and requests-per-minute measurement
- **Boot Auto-start** — Boot broadcast relay so apps can reconnect after device restart
- **Zero Persistence** — No database, no shared preferences, no file I/O for user data in the Dart layer

### Platform Support

| Platform | Status |
|---|---|
| Android (API 23+) | ✅ |
| iOS | 🔧 In Development |
| macOS | 🔧 In Development |
| Windows | 🗓 Planned |
| Linux | 🗓 Planned |

### Sing-box Core

Bundled with Sing-box `1.14.0-alpha.20` via gomobile-generated `libbox.aar`.
