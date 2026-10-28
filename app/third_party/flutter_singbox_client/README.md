# flutter_singbox_client

[![Open Source Love](https://badges.frapsoft.com/os/v1/open-source.svg?v=103)](#)
[![License](https://img.shields.io/github/license/amir-zr/flutter_singbox_client)](LICENSE)
[![Stars](https://img.shields.io/github/stars/amir-zr/flutter_singbox_client)](https://github.com/amir-zr/flutter_singbox_client/stargazers)
[![Forks](https://img.shields.io/github/forks/amir-zr/flutter_singbox_client)](https://github.com/amir-zr/flutter_singbox_client/network/members)
[![Issues](https://img.shields.io/github/issues/amir-zr/flutter_singbox_client)](https://github.com/amir-zr/flutter_singbox_client/issues)
[![Release](https://img.shields.io/github/release/amir-zr/flutter_singbox_client)](https://github.com/amir-zr/flutter_singbox_client/releases)
[![pub package](https://img.shields.io/pub/v/flutter_singbox_client.svg)](https://pub.dev/packages/flutter_singbox_client)
[![pub likes](https://img.shields.io/pub/likes/flutter_singbox_client)](https://pub.dev/packages/flutter_singbox_client/score)
[![pub points](https://img.shields.io/pub/points/flutter_singbox_client)](https://pub.dev/packages/flutter_singbox_client/score)

> [!TIP]
> ### 🚀 Flutter Sing-box on Android, iOS, Windows, macOS & Linux — iOS App Store Safe
>
> [<img src="https://img.shields.io/badge/📸_Screenshots-6e5494?style=for-the-badge" height="40">](#screenshots) [<img src="https://img.shields.io/badge/📱_Platforms-6e5494?style=for-the-badge" height="40">](#supported-platforms)

**flutter_singbox_client** is a Flutter plugin that embeds the [Sing-box](https://github.com/SagerNet/sing-box) proxy/VPN core for building cross-platform VPN and proxy apps.

Clean, stateless, event-driven Dart API. **Lightweight · Stateless · Engine-focused**

---

## Features

| Feature | Description |
|---|---|
| 🔒 **VPN Mode** | Full device-wide TUN tunnel via Android `VpnService` |
| 🌐 **Proxy Mode** | HTTP/SOCKS proxy without a TUN device, no permission required |
| ⚔️ **Clash API** | Runtime mode switching and outbound group control with latency testing |
| 📱 **Per-App Proxy** | Include or exclude specific apps from the tunnel (split tunneling) |
| 🌍 **System Proxy** | Register HTTP inbound as device-wide proxy on Android Q+ |
| 🔑 **Kill Switch** | Block all traffic at the OS level when the tunnel is down |
| 📊 **Live Traffic** | Real-time upload/download speeds and session totals at ~1 Hz |
| 🔌 **Connection Tracking** | Full per-connection metadata, lifecycle, and close control |
| 📋 **Live Logs** | Real-time Go core log streaming with per-level filtering |
| ⚠️ **Fault Alerts** | Dedicated fault stream for actionable service errors |
| 🧠 **Memory Limits** | Go runtime soft memory cap (`GOMEMLIMIT`) with optional connection kill |
| 🧪 **Network Testing** | Built-in STUN (NAT type, latency) and network quality (speed, RPM) tests |
| ✅ **Config Validation** | Go core validation and JSON formatting before connecting |
| 🔄 **Hot Reload** | Reload config without restarting the service or dropping connections |
| 🚀 **Boot Auto-start** | Boot broadcast relay so your app can reconnect after device restart |
| 📦 **Zero Persistence** | No database, no shared preferences, no file I/O for user data |

---

## Screenshots

| Home | Logs | Network Test |
|:---:|:---:|:---:|
| ![Home](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_home.jpg) | ![Logs](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_logs.jpg) | ![Network Test](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_network_test.jpg) |

| Per-App Proxy | Settings | Settings (2) |
|:---:|:---:|:---:|
| ![Per-App Proxy](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_per_app_proxy.jpg) | ![Settings](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_settings_1.jpg) | ![Settings (2)](https://raw.githubusercontent.com/amir-zr/flutter_singbox_client/main/screenshots/flutter_singbox_client_settings_2.jpg) |

---

## Sing-Box Supported Protocols & Features

`VMess` · `VLESS` · `Trojan` · `Shadowsocks` · `Hysteria2` · `TUIC` · `WireGuard` · `ShadowTLS` · `AnyTLS` · `Naive` · `Tor` · `SSH`

Includes full support for V2Ray transports (WebSocket, gRPC, HTTPUpgrade, QUIC), TLS security (uTLS, Reality, ECH, ACME), FakeIP DNS, rule-based routing, and anti-censorship obfuscation.

➡️ See [Supported Protocols & Features](doc/supported-protocols.md) for the complete reference.

---

## Supported Platforms

Cross-platform Flutter Sing-box SDK for **Android**, **iOS**, **Windows**, **macOS**, and **Linux** VPN / proxy apps.

| Platform | Status | Core | Availability |
|---|---|---|---|
| Android | ✅ Done | Sing-box 1.14.0-alpha.20 | Free |
| iOS | ✅ Done | Sing-box 1.14.0-alpha.45 | [Buy Now](https://t.me/AmirZrDevv) |
| Windows | ✅ Done | Sing-box 1.14.0-alpha.45 | [Buy Now](https://t.me/AmirZrDevv) |
| macOS | ✅ Done | Sing-box 1.14.0-alpha.45 | [Buy Now](https://t.me/AmirZrDevv) |
| Linux | ✅ Done | Sing-box 1.14.0-alpha.45 | [Buy Now](https://t.me/AmirZrDevv) |

### iOS (App Store Safe)

Build Flutter VPN and proxy apps for **iPhone** and **iPad** with Sing-box — designed for App Store–compatible Network Extension workflows. Premium build: [Buy Now](https://t.me/AmirZrDevv).

### Desktop — Windows, macOS & Linux

Ship desktop VPN / system-proxy clients on **Windows**, **macOS**, and **Linux** with the same Dart API as mobile. Ideal for Flutter desktop Sing-box apps that need TUN or local HTTP/SOCKS proxy. Premium builds: [Buy Now](https://t.me/AmirZrDevv).

> 💡 Questions about iOS or desktop licensing? [Contact @AmirZrDevv on Telegram](https://t.me/AmirZrDevv).

---

## Requirements

| Requirement | Minimum |
|---|---|
| Flutter SDK | `>=3.19.0` |
| Dart SDK | `>=3.3.0` |
| Android `minSdk` | 23 (Marshmallow) |
| Android `compileSdk` | 35 |
| Java target | 17 |

---

## Installation

**1. Add the dependency** (`pubspec.yaml`):

```yaml
dependencies:
  flutter_singbox_client: ^1.1.0
```

**2. Configure Android Gradle** (`android/app/build.gradle`):

```gradle
android {
    compileSdk 35
    defaultConfig { minSdk 23 }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
```

**3. Permissions** — declared in the SDK manifest and merged automatically. See [Android Permissions](doc/android-permissions.md) for optional and sensitive permissions.

---

## Quick Start

```dart
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

final client = SingboxClient();

// Initialize once at app startup
await client.initialize();

// Request VPN permission (VPN mode only)
if (!await client.requestVPNPermission()) return;

// Validate config — throws with the Go core's error message on failure
try {
  await client.checkConfig(myConfigJson);
} catch (e) {
  showError('$e');
  return;
}

// Connect
await client.connect(SessionOptions(
  config: myConfigJson,
  networkMode: NetworkMode.vpn,
  notification: NotificationConfig(
    title: 'My VPN',
    showTrafficStats: true,
    showStopButton: true,
    stopButtonLabel: 'Disconnect',
  ),
));

// Subscribe to live events
client.serviceStateStream.listen((state) => print('State: $state'));
client.trafficStatsStream.listen((s) => print('↑${s.uplinkBps} ↓${s.downlinkBps}'));
client.faultStream.listen((error) => showSnackbar(error));

// Disconnect
await client.disconnect();
```

---

## VPN Mode vs Proxy Mode

Select the operating mode via `SessionOptions.networkMode`.

| | VPN Mode | Proxy Mode |
|---|---|---|
| **Android service** | `VpnService` | Foreground `Service` |
| **TUN device** | ✅ | ❌ |
| **Traffic capture** | System-wide at OS level | Manual (apps must use the proxy) |
| **VPN permission required** | ✅ | ❌ |
| **Kill switch** | ✅ | ❌ |
| **System proxy** | ✅ (Android Q+) | ❌ |
| **Per-app routing** | ✅ | ❌ |
| **`tun` inbound in config** | Required for auto-route | Must not be present |

Use `NetworkMode.vpn` when your config uses `"type": "tun"` or `"auto_route": true`, or when you need kill switch, per-app routing, or system proxy.

Use `NetworkMode.proxy` when you only need HTTP/SOCKS proxy ports without requesting VPN permission.

> [!WARNING]
> Proxy mode configs must **not** contain a `tun` inbound. Starting proxy mode with a TUN config causes an immediate startup failure via `faultStream`.

---

## Documentation

| Guide | Contents |
|---|---|
| [Getting Started](doc/getting-started.md) | Initialization, lifecycle, config validation, traffic, outbound groups, Clash mode, connections, network testing, system proxy, boot |
| [API Reference](doc/api-reference.md) | All methods and event streams |
| [Data Models](doc/models.md) | Field reference for every SDK type |
| [Best Practices](doc/best-practices.md) | Integration patterns, pitfalls, and a full example |
| [Supported Protocols & Features](doc/supported-protocols.md) | All Sing-box protocols, transports, TLS, DNS, routing, and obfuscation |
| [Android Permissions](doc/android-permissions.md) | Required, optional, and sensitive permissions |
| [Troubleshooting](doc/troubleshooting.md) | Common errors and fixes |

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE) (GPL-3.0).

---

## Attribution

This project uses third-party libraries and resources. See [ATTRIBUTION.md](ATTRIBUTION.md) for details.

---

## Donation

If you like this package, consider supporting continued development of the free Android SDK and premium **iOS** / **Windows** / **macOS** / **Linux** builds.

[![Buy Me A Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=amirzr.dev&button_colour=FFDD00&font_colour=000000&font_family=Comic&outline_colour=000000&coffee_colour=ffffff)](https://www.buymeacoffee.com/amirzr.dev)
