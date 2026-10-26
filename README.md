# Viva la Resistance

Android-клиент для доступа к YouTube и Instagram. Через туннель идут **только домены выбранных сервисов**, остальной трафик — напрямую.

## Стек

- **UI:** Flutter / Dart
- **VPN-ядро:** [sing-box](https://github.com/SagerNet/sing-box) (GPL-3.0), собранное в `libbox.aar` через gomobile
- **Протокол:** VLESS + Reality (TCP/443)
- **Роутинг:** sing-box `rule_set` (локальные `.srs` для `youtube` и `instagram`)

## Лицензия

Проект распространяется под **GNU GPL-3.0** (см. `LICENSE`). Используется sing-box под GPL-3.0; точная версия и ссылка на исходники — в `NOTICE`.

## Сборка

Требуется: Flutter 3.19+, JDK 17, Android SDK + NDK, Go 1.23+, gomobile.

```bash
# 1) списки доменов
tools/fetch-rulesets.sh

# 2) ядро (libbox.aar) — один раз
tools/build-libbox.sh

# 3) свой сервер
cp app/assets/config.example.json app/assets/config.local.json
# заполнить address/uuid/reality_public_key/reality_short_id/server_name

# 4) APK
cd app && flutter pub get && flutter build apk --release
```

`config.local.json` и `server/.env` в `.gitignore` — свои секреты не коммитить.

## Свой сервер

Инструкция: `server/README.md`.

## Структура

```
app/                  Flutter-приложение
server/               пример конфигурации sing-box + docker-compose
tools/                сборка libbox и загрузка rule-set
```
