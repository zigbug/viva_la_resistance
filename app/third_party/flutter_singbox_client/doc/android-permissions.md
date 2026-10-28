# Android Permissions

## Auto-Merged (no action required)

These permissions are declared in the SDK's `AndroidManifest.xml` and merged into your app automatically.

| Permission | Purpose |
|---|---|
| `INTERNET` | Outbound VPN/proxy connections |
| `ACCESS_NETWORK_STATE` | `ConnectivityManager` callbacks for network interface tracking |
| `CHANGE_NETWORK_STATE` | `ConnectivityManager.requestNetwork()` on API 28–30 |
| `ACCESS_WIFI_STATE` | WiFi SSID/BSSID for `wifi_ssid` routing rules |
| `FOREGROUND_SERVICE` | Required to call `startForeground()` |
| `FOREGROUND_SERVICE_SYSTEM_EXEMPTED` | `systemExempted` service type for `SingboxVPNService` (API 34+) |
| `FOREGROUND_SERVICE_SPECIAL_USE` | `specialUse` service type for `SingboxProxyService` (API 34+) |
| `POST_NOTIFICATIONS` | Foreground notification (runtime permission on API 33+) |
| `RECEIVE_BOOT_COMPLETED` | Receives boot broadcast and re-broadcasts to the host app |

> **`POST_NOTIFICATIONS`** is declared in the SDK manifest but must be **requested at runtime** by your app on Android 13+ (API 33+). The service runs without it but the notification is suppressed, which violates foreground service visibility requirements.

---

## Optional

Add to your app manifest only when the specific feature is needed.

**Doze-mode exemption** — keeps VPN running when the screen is off:

```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

**WiFi SSID routing rules** — enables `wifi_ssid` / `wifi_bssid` match conditions:

```xml
<!-- API 26–28 -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- API 29+ -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

> **Warning:** Location permissions are dangerous runtime permissions and require prominent in-app disclosure and Privacy Policy documentation per Google Play policy. Only request them if your configs actively use SSID-based routing rules.

---

## Sensitive (Google Play Declaration Required)

**`QUERY_ALL_PACKAGES`** — only needed if you build an app picker for per-app proxy (split tunneling). The SDK itself does not enumerate packages.

```xml
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

Declaring this without prior Play Console approval violates Google Play policy for apps targeting API 30+. Submit a Permissions Declaration Form in **Play Console → Policy → App content → Sensitive Permissions** before publishing.

**Alternative with no declaration required:** Use `<queries>` to target only specific known packages:

```xml
<queries>
    <package android:name="com.android.chrome" />
    <package android:name="org.telegram.messenger" />
</queries>
```
