# Сервер: sing-box + VLESS+Reality

Схема на VPS:

```
Интернет :443
   │
   ├─ HAProxy (SNI-роутинг)
   │     ├─ SNI vlr.example.com → 127.0.0.1:8449  sing-box (VLESS+Reality)
   │     └─ everything else     → 127.0.0.1:8447  mtg (mtproto, PROXY v2)
   │
   └─ nginx :9446 (только localhost) — сайт-прикрытие для Reality
```

Reality(сервер) при незнакомом TLS-клиенте проксирует рукопожатие на прикрытие
`127.0.0.1:9446`. Поэтому любой активный зонд видит наш настоящий сайт с валидным
сертификатом, а не «чужой» домен.

## 1. Домен и сертификат

A-запись `vlr.example.com` → IP сервера. Затем сертификат (HTTP-01):

```bash
certbot certonly --webroot -w /var/www/certbot -d vlr.example.com \
  --non-interactive --agree-tos --register-unsafely-without-email
```

## 2. Ключи

```bash
docker run --rm ghcr.io/sagernet/sing-box:v1.14.4 generate reality-keypair
docker run --rm ghcr.io/sagernet/sing-box:v1.14.4 generate uuid
openssl rand -hex 8
```

## 3. sing-box

```bash
mkdir -p /opt/sb-server && cd /opt/sb-server
cp <repo>/server/docker-compose.yml .
cp <repo>/server/config.example.json config.json
chmod 600 config.json
# вписать uuid/private_key/short_id/server_name
docker compose up -d
docker logs sb-reality
```

## 4. nginx-прикрытие

`server/nginx-vpn.conf.example` → `/etc/nginx/sites-available/vlr.example.com`,
symlink в `sites-enabled`, `nginx -t && systemctl reload nginx`.

## 5. HAProxy (забирает 443 у nginx)

`server/haproxy.cfg.example` → `/etc/haproxy/haproxy.cfg`, затем:

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg
# убрать 443/stream из nginx, если он там был
systemctl enable --now haproxy
```

## 6. Проверка

```bash
# прикрытие / активный зонд
openssl s_client -connect 127.0.0.1:443 -servername vlr.example.com </dev/null

# сам туннель (sing-box клиент с SOCKS)
curl --socks5-hostname 127.0.0.1:10808 https://api.ipify.org

# лог сервера должен показать
#   REALITY: processed invalid connection   (зонд)
#   inbound connection to ...               (валидный клиент)
docker logs sb-reality
```

## Клиент

Android-клиент — Flutter-приложение из этого репозитория (см. корневой `README.md`).
Он использует `flutter_singbox_client` (встроенный sing-box), поэтому собирать
`libbox.aar` вручную не нужно.

Важно: `server_name` в `app/assets/config.local.json` должен **точно совпадать**
с `server_name` в серверном конфиге (`vlr.905911.ru`). При несовпадении SNI
Reality считает соединение чужим и уводит его в прикрытие (mtg/nginx).

A-запись домена нужна для валидного сертификата прикрытия и внешней проверки.
Сам туннель работает и без неё: клиент подключается по IP, а SNI передаёт
отдельно. После создания A-записи выпустите Let's Encrypt сертификат (шаг 1)
и переключите nginx-прикрытие на `/etc/letsencrypt/live/...`.

## Параметры клиента

| Поле | Значение |
| --- | --- |
| address | IP сервера |
| port | 443 |
| uuid | из users[] |
| flow | xtls-rprx-vision |
| server_name | vlr.example.com |
| reality_public_key | PublicKey из `generate reality-keypair` |
| reality_short_id | из `short_id[]` |
