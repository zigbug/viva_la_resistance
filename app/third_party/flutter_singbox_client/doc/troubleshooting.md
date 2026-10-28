# Troubleshooting

## "Core failed: bad file descriptor" — TUN inbound in proxy mode

```
Core failed: start or reload service: start inbound/tun[0]: configure tun
interface: query tun name: failed to get name of TUN device: bad file descriptor
```

Your config contains a `tun` inbound but the service was started with `NetworkMode.proxy`. Proxy mode never opens a TUN device.

**Fix A — Switch to VPN mode:**

```dart
await client.connect(SessionOptions(
  config: yourConfig,
  networkMode: NetworkMode.vpn,
));
```

**Fix B — Remove the `tun` inbound from your config:**

Keep only `http`, `socks`, or `mixed` inbounds, and remove `"auto_detect_interface": true` from `route`.

| Config contains | Required mode |
|---|---|
| `"type": "tun"` inbound | `NetworkMode.vpn` |
| `"auto_route": true` | `NetworkMode.vpn` |
| Only `http` / `socks` / `mixed` inbounds | Either mode |

---

## Service starts but no traffic flows

1. Confirm the config passes `checkConfig()` without error.
2. Confirm the correct `networkMode` for your config (see above).
3. Subscribe to `faultStream` — it carries the Go core's exact error message.
4. Check `coreLogStream` for `error` or `fatal` level entries at startup.
5. In VPN mode: confirm `requestVPNPermission()` returned `true`.
6. In VPN mode: confirm no other VPN app is currently active on the device.

---

## `faultStream` fires immediately after `connect()`

The Go core failed to start. Common causes and fixes:

| Cause | Fix |
|---|---|
| Invalid config syntax | Run `checkConfig()` before connecting |
| `tun` inbound in proxy mode | Use `NetworkMode.vpn` or remove the inbound |
| VPN permission not granted | Check `requestVPNPermission()` return value |
| Another VPN is already active | Ask the user to disconnect it first |
| Port already in use | Check config inbound ports for conflicts |

---

## Config validation passes but connect fails

`checkConfig()` validates config syntax and structure. Some failures only surface at runtime (network unreachable, DNS failure, port conflict). Always subscribe to `faultStream` to catch these.

---

## Notification not visible on Android 13+

`POST_NOTIFICATIONS` is a runtime permission on API 33+. The service runs without it, but Android silently suppresses the notification — which violates foreground service visibility requirements.

```dart
await Permission.notification.request(); // using permission_handler
```

Request this before calling `connect()`.

---

## VPN disconnects when screen turns off

Android's Doze mode can kill foreground services on aggressive battery profiles. Add the exemption permission and prompt the user:

```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

```dart
await Permission.ignoreBatteryOptimizations.request();
```

---

## Kill switch blocks all traffic after disconnect

Kill switch (`killSwitch: true`) blocks all traffic at the OS level while the VPN tunnel is down — including after a normal `disconnect()`. This is the intended behaviour of Android's always-on VPN feature. To restore normal connectivity, the user must either reconnect or disable the kill switch (requires a new `connect()` with `killSwitch: false`).

---

## `selectOutbound()` has no effect

`selectOutbound()` only works on groups where `selectable == true`. URL-test groups (`type == 'urltest'`) manage their own selection automatically and do not support manual selection.

---

## Clash modes list is empty

`clashModesStream` only emits if your config includes a `clash_api` block with named modes. Without it, the list is always empty.

```json
{
  "experimental": {
    "clash_api": {
      "default_mode": "rule"
    }
  }
}
```

---

## Memory usage keeps growing

If you observe the Go runtime heap (`TrafficStats.memoryBytes`) growing without bound:

1. Enable `MemoryLimitConfig` with a limit appropriate for the target device.
2. Set `killConnections: true` if you want connections dropped aggressively when the cap is hit.
3. Note that `limitMb` is a *soft* cap — the Go runtime will exceed it briefly during GC cycles.

```dart
await client.connect(SessionOptions(
  config: configJson,
  memoryLimit: MemoryLimitConfig(enabled: true, limitMb: 150),
));
```

---

## Boot auto-start not working

1. Confirm `RECEIVE_BOOT_COMPLETED` is in the merged manifest (it is — declared by the SDK).
2. On Android 12+ (API 31+), apps must have been launched at least once by the user before they can receive boot broadcasts.
3. The SDK's `BootReceiver` only re-broadcasts `dev.amirzr.singbox.DEVICE_BOOTED` — your app must register its own receiver and handle the actual re-launch logic. See [Getting Started — Boot Auto-start](getting-started.md#boot-auto-start).
