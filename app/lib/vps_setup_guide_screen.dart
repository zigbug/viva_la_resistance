import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VpsSetupGuideScreen extends StatelessWidget {
  const VpsSetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройка VPS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Section(
              title: 'Что нужно',
              child: const _Bullets(items: [
                'VPS с публичным IP, Linux (Ubuntu/Debian и т.п.).',
                'Доступ по SSH (обычно пользователь root или sudo).',
                'Открытый входящий TCP-порт 443 в файрволе VPS и в панели хостера/облака.',
                'Домен/сайт для маскировки Reality (SNI): реальный домен с рабочим TLS 1.3, который вы укажете как server_name.',
                'Синхронизированное время на сервере (NTP).',
              ]),
            ),
            _Section(
              title: '1. Подключитесь к серверу и подготовьте систему',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Подключение по SSH (замените IP):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('ssh root@<IP_СЕРВЕРА>'),
                  const SizedBox(height: 10),
                  Text('Обновите пакеты (Debian/Ubuntu):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('apt update'),
                  const SizedBox(height: 6),
                  const _CodeBlock('apt upgrade -y'),
                  const SizedBox(height: 10),
                  Text('Установите curl (если нет):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('apt install -y curl'),
                  const SizedBox(height: 10),
                  Text('Включите синхронизацию времени (важно для Reality):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('timedatectl set-ntp true'),
                ],
              ),
            ),
            _Section(
              title: '2. Установите sing-box',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Официальный скрипт установки (скачивает и устанавливает sing-box как сервис):',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock(
                      'curl -fsSL https://sing-box.app/install.sh | bash'),
                  const SizedBox(height: 10),
                  Text('Проверьте, что sing-box установлен:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('sing-box version'),
                  const SizedBox(height: 10),
                  Text(
                    'Если `sing-box` не найден после установки, откройте новую SSH-сессию или выполните:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock('hash -r'),
                ],
              ),
            ),
            _Section(
              title: '3. Сгенерируйте UUID, ключи Reality и short_id',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сгенерируйте UUID клиента (сохраните значение):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('sing-box generate uuid'),
                  const SizedBox(height: 10),
                  Text(
                    'Сгенерируйте пару ключей Reality. Будут выведены PrivateKey и PublicKey:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock('sing-box generate reality-keypair'),
                  const SizedBox(height: 6),
                  Text(
                    'PrivateKey — только в конфиг сервера. PublicKey — в приложение.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Сгенерируйте short_id (hex, например 8 байт):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('openssl rand -hex 8'),
                ],
              ),
            ),
            _Section(
              title: '4. Откройте порт 443 в файрволе (если включён)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Для UFW (Ubuntu):', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('ufw allow 443/tcp'),
                  const SizedBox(height: 10),
                  Text('Для firewalld (CentOS/RHEL/Alma и др.):',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock(
                      'firewall-cmd --permanent --add-port=443/tcp'),
                  const SizedBox(height: 6),
                  const _CodeBlock('firewall-cmd --reload'),
                  const SizedBox(height: 8),
                  Text(
                    'Также проверьте правила файрвола в панели вашего хостера/облака (Security Groups).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: '5. Создайте конфигурацию сервера',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Создайте каталог конфигурации (если его нет):',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock('mkdir -p /etc/sing-box'),
                  const SizedBox(height: 10),
                  Text(
                    'Откройте файл конфигурации в редакторе:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock('nano /etc/sing-box/config.json'),
                  const SizedBox(height: 10),
                  Text(
                    'Вставьте конфиг ниже и замените <UUID>, <SNI_домен>, <REALITY_PRIVATE_KEY>, <SHORT_ID> на свои значения. '
                    'Сохраните (в nano: Ctrl+O, Enter, Ctrl+X):',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  const _CodeBlock('''{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": 443,
      "users": [
        {
          "uuid": "<UUID>",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "<SNI_домен>",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "<SNI_домен>",
            "server_port": 443
          },
          "private_key": "<REALITY_PRIVATE_KEY>",
          "short_id": [
            "<SHORT_ID>"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}'''),
                ],
              ),
            ),
            _Section(
              title: '6. Проверка, запуск и автозапуск',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Проверьте конфигурацию на ошибки:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('sing-box check -c /etc/sing-box/config.json'),
                  const SizedBox(height: 10),
                  Text('Включите автозапуск сервиса:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('systemctl enable sing-box'),
                  const SizedBox(height: 10),
                  Text('Перезапустите sing-box:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('systemctl restart sing-box'),
                  const SizedBox(height: 10),
                  Text('Проверьте статус сервиса:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('systemctl status sing-box'),
                  const SizedBox(height: 10),
                  Text('Смотрите логи при необходимости:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('journalctl -u sing-box -e'),
                  const SizedBox(height: 10),
                  Text('Убедитесь, что порт 443 слушается:',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  const _CodeBlock('ss -ltnp | grep 443'),
                ],
              ),
            ),
            _Section(
              title: '7. Что ввести в приложении',
              child: const _MapTable(rows: [
                ['Адрес сервера', 'Публичный IP (или домен) вашего VPS'],
                ['Порт', 'listen_port сервера (обычно 443)'],
                ['UUID', 'UUID из users[].uuid (команда `sing-box generate uuid`)'],
                ['Flow', 'xtls-rprx-vision (как на сервере)'],
                ['SNI / server_name', 'Домен маскировки Reality (tls.server_name / handshake.server)'],
                ['Reality public key', 'PublicKey из `sing-box generate reality-keypair` (НЕ private)'],
                ['Reality short id', 'Один из short_id, заданных на сервере (например вывод `openssl rand -hex 8`)'],
              ]),
            ),
            _Section(
              title: 'Замечания и диагностика',
              child: const _Bullets(items: [
                'SNI (server_name) должен быть реальным, доступным доменом с TLS 1.3 — от этого зависит маскировка Reality.',
                'PrivateKey никогда не вводится в приложение; в приложении используется только PublicKey.',
                'Если рукопожатие не проходит: проверьте совпадение UUID, Public/Private key пары, short_id, SNI и порта на сервере и в приложении.',
                'Если нет соединения: проверьте, что 443/tcp открыт в файрволе ОС и у хостера, сервис запущен (`systemctl status sing-box`), порт слушается (`ss -ltnp | grep 443`).',
                'При ошибках смотрите логи сервера: `journalctl -u sing-box -e` и при необходимости временно повысьте уровень лога до debug в config.json.',
                'Устойчивость к DPI зависит не только от клиента, но и от выбора/состояния SNI-домена и качества сервера.',
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.textTheme.bodyMedium),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              code,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: 'Копировать',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTable extends StatelessWidget {
  const _MapTable({required this.rows});
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    row[0],
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(row[1], style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
