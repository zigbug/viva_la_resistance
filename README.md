# Viva la Resistance

Android-клиент для выборочного доступа к **YouTube** и **Instagram**.
Трафик остальных приложений и сайтов идёт напрямую, без VPN.

## Что умеет

- Одна большая кнопка «Подключить / Отключить».
- Два режима в «Расширенных»:
  - **Домены** — VPN для всего устройства, но через сервер идут только домены
    выбранных сервисов (`geosite-youtube`, `geosite-instagram`), остальное —
    напрямую. Работает и в браузере.
  - **Приложения** — VPN только для выбранных приложений (per-app include).
    Весь трафик этих приложений идёт через сервер, остальные приложения
    вообще не попадают в туннель.
- Чекбоксы YouTube / Instagram: можно включить только один сервис.
- Живая статистика скорости, статус, ошибки ядра.
- Серверные параметры не редактируются в приложении: только локальный
  `config.local.json` на этапе сборки.

## Стек

- **UI:** Flutter / Dart
- **VPN-ядро:** [sing-box](https://github.com/SagerNet/sing-box) через
  [`flutter_singbox_client`](https://github.com/amir-zr/flutter_singbox_client)
  (GPL-3.0-only). Плагин уже содержит `libbox.aar` для Android —
  отдельная сборка ядра не нужна.
- **Протокол:** VLESS + Reality, TCP/443 (SNI-мультиплексирование с mtg).
- **Роутинг:** локальные `rule_set` `.srs` для YouTube и Instagram.

Плагин бесплатен для Android; iOS/Windows/macOS/Linux у него платные, но нам
они не нужны. Встроенное ядро — `sing-box 1.14.0-alpha.20`; сервер работает на
стабильном `v1.14.4`, конфиги совместимы (проверено `sing-box check`).

## Требования

| Компонент | Версия |
| --- | --- |
| Flutter | >= 3.38 (проверено на 3.47.8) |
| Dart | >= 3.10 |
| JDK | 17 |
| Android SDK | compileSdk 36, minSdk 24 |

NDK и Go для сборки APK **не нужны**: нативное ядро приходит готовым AAR
внутри плагина.

## Сборка

```bash
# 1) зависимости
cd app
flutter pub get

# 2) серверные параметры (файл в .gitignore)
cp assets/config.example.json assets/config.local.json
$EDITOR assets/config.local.json

# 3) APK
flutter build apk --release
```

Готовый файл: `app/build/app/outputs/flutter-apk/app-release.apk`.

`libbox.aar` внутри плагина содержит нативные библиотеки сразу для четырёх ABI,
поэтому универсальный APK весит ~200 МБ (`--target-platform` на размер не влияет).
Для телефона собирайте APK на каждый ABI и ставьте `arm64-v8a`:

```bash
flutter build apk --release --split-per-abi
# app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (~70 МБ)
```

Если нужен ровно один файл, можно ограничить ABI в `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    ndk { abiFilters += listOf("arm64-v8a") }
}
```

Сейчас release подписывается debug-ключом (так в шаблоне Flutter): для личной
установки этого достаточно, для публикации в магазине нужен свой keystore
(`android/key.properties`, он в `.gitignore`).

Для отладочной сборки: `flutter run` или `flutter build apk --debug`.

### Заполнение config.local.json

```json
{
  "name": "Viva la Resistance",
  "address": "203.0.113.10",
  "port": 443,
  "uuid": "UUID клиента",
  "flow": "xtls-rprx-vision",
  "server_name": "vpn.905911.ru",
  "reality_public_key": "PUBLIC KEY",
  "reality_short_id": "SHORT ID",
  "services": { "youtube": true, "instagram": true }
}
```

Значения `uuid`, `reality_public_key`, `reality_short_id` и `server_name`
берутся с сервера из `/opt/sb-server/config.json` (там же `private_key`,
который клиенту не нужен). **Не коммитьте** `config.local.json`.

`packages` — необязательный блок: можно переопределить список Android-пакетов
для режима «Приложения» (по умолчанию YouTube, YouTube ReVanced и Instagram).

## Как это работает

1. Flutter собирает конфиг sing-box: TUN-инбаунд, DNS, VLESS+Reality outbound,
   локальные rule-set и правила маршрутизации.
2. В режиме «Домены» правило `rule_set -> proxy` стоит перед `final: direct`.
   Домены YouTube/Instagram определяются по TLS/QUIC SNI.
3. В режиме «Приложения» `perAppProxy: include` ограничивает TUN выбранными
   пакетами, а `final: proxy` отправляет весь их трафик на сервер.
4. DNS: запросы к доменам выбранных сервисов идут через прокси, остальные —
   напрямую. В режиме «Приложения» весь DNS идёт через прокси.

Приватные адреса (`ip_is_private`) всегда идут напрямую.

## Сервер

Пример конфигурации HAProxy + sing-box + nginx-прикрытия: [`server/README.md`](server/README.md).

Текущая схема на VPS:

```
:443 HAProxy
  ├─ SNI vpn.905911.ru → 127.0.0.1:8449  sing-box VLESS+Reality
  └─ остальное         → 127.0.0.1:8447  mtg (Telegram)
```

Reality при неизвестном клиенте проксирует рукопожатие на локальный
nginx-прикрытие, поэтому активный зонд видит настоящий сайт. Для валидного
сертификата нужна A-запись `vpn.905911.ru` и Let's Encrypt (см. server/README).

## Проверка

```bash
cd app
flutter analyze
flutter test
```

Тесты проверяют структуру конфига для обоих режимов. Дополнительно конфиг
можно проверить реальным ядром:

```bash
sing-box check -c config.json
```

## Лицензия

Проект распространяется под **GNU GPL-3.0** (см. `LICENSE`). Проект использует
sing-box и flutter_singbox_client (GPL-3.0-only); версии, ссылки на исходники и
атрибуция — в [`NOTICE`](NOTICE).

## Структура

```
app/                  Flutter-приложение
  lib/                UI, конфиг, VPN-контроллер
  assets/             config.example.json + rule-sets/*.srs
server/               примеры sing-box, HAProxy, nginx, docker-compose
tools/fetch-rulesets.sh
```
