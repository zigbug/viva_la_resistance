import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

import 'vpn_controller.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, required this.controller});
  final VpnController controller;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.controller.addListener(_onControllerChange);
    _searchController.addListener(_onSearchChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _onSearchChange() {
    widget.controller.setLogSearchQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал и соединения'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(icon: Icon(Icons.terminal), text: 'Логи ядра'),
            Tab(icon: Icon(Icons.link), text: 'Соединения'),
          ],
        ),
        actions: [
          if (_tabController.index == 0) _LogFilterMenu(controller: widget.controller),
          IconButton(
            tooltip: 'Экспорт',
            icon: const Icon(Icons.download),
            onPressed: _exportCurrentTab,
          ),
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearCurrentTab,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tabController.index == 0) _buildSearchBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogList(),
                _buildConnectionList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Поиск по сообщению...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    widget.controller.setLogSearchQuery('');
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLogList() {
    final entries = widget.controller.filteredLogs;
    if (entries.isEmpty) {
      return const Center(child: Text('Логов пока нет. Подключитесь к VPN.'));
    }
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _LogEntryTile(entry: entry);
      },
    );
  }

  Widget _buildConnectionList() {
    final entries = widget.controller.connections;
    if (entries.isEmpty) {
      return const Center(child: Text('Соединений пока нет. Подключитесь к VPN.'));
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final conn = entries[index];
        return _ConnectionTile(conn: conn);
      },
    );
  }

  void _exportCurrentTab() {
    if (_tabController.index == 0) {
      final text = widget.controller.exportLogs(filtered: true);
      _shareText(text, 'viva_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
    } else {
      final csv = widget.controller.exportConnectionsCsv();
      _shareText(csv, 'viva_connections_${DateTime.now().millisecondsSinceEpoch}.csv');
    }
  }

  void _clearCurrentTab() {
    if (_tabController.index == 0) {
      widget.controller.clearLogs();
    } else {
      widget.controller.clearConnections();
    }
  }

  Future<void> _shareText(String text, String filename) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скопировано: $filename')),
    );
  }
}

class _LogFilterMenu extends StatelessWidget {
  const _LogFilterMenu({required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LogLevel>(
      tooltip: 'Уровень логирования',
      icon: const Icon(Icons.filter_list),
      initialValue: controller.logFilterLevel,
      onSelected: controller.setLogFilterLevel,
      itemBuilder: (context) => LogLevel.values.map((level) {
        return PopupMenuItem(
          value: level,
          child: Row(
            children: [
              _LevelColorDot(level),
              const SizedBox(width: 8),
              Text(level.name.toUpperCase()),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LevelColorDot extends StatelessWidget {
  const _LevelColorDot(this.level);
  final LogLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      LogLevel.trace => Colors.grey,
      LogLevel.debug => Colors.blue,
      LogLevel.info => Colors.green,
      LogLevel.warn => Colors.orange,
      LogLevel.error => Colors.red,
      LogLevel.fatal => Colors.deepOrange,
      LogLevel.panic => Colors.purple,
    };
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});
  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = switch (entry.level) {
      LogLevel.trace => isDark ? Colors.grey[400] : Colors.grey[600],
      LogLevel.debug => isDark ? Colors.blue[300] : Colors.blue[700],
      LogLevel.info => isDark ? Colors.green[300] : Colors.green[700],
      LogLevel.warn => isDark ? Colors.orange[300] : Colors.orange[700],
      LogLevel.error => isDark ? Colors.red[300] : Colors.red[700],
      LogLevel.fatal => isDark ? Colors.deepOrange[300] : Colors.deepOrange[700],
      LogLevel.panic => isDark ? Colors.purple[300] : Colors.purple[700],
    };

    return Container(
      color: color?.withValues(alpha: 0.05),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 4,
          color: color,
        ),
        title: Text(
          entry.message,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 11,
            color: color,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${entry.time.toLocal().toString().substring(11, 23)} [${entry.level.name.toUpperCase()}]',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        onLongPress: () => _copyToClipboard(context, entry.toString()),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано в буфер обмена')),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.conn});
  final ConnectionInfo conn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = conn.isActive;
    final isProxy = conn.outboundType == 'vless' || conn.outbound.contains('proxy');
    final isDirect = conn.outboundType == 'direct' || conn.outbound == 'direct';

    Color statusColor;
    if (isActive) {
      statusColor = Colors.green;
    } else if (isProxy) {
      statusColor = Colors.blue;
    } else if (isDirect) {
      statusColor = Colors.grey;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            isActive ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: statusColor,
          ),
        ),
        title: Text(
          conn.domain.isNotEmpty ? conn.domain : conn.destination,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${conn.network.toUpperCase()} • ${conn.protocol.toUpperCase()} • ${conn.chain.isNotEmpty ? conn.chain : conn.outbound} • ${_formatBytes(conn.uplinkTotalBytes)}↑ ${_formatBytes(conn.downlinkTotalBytes)}↓',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isProxy ? Colors.blue : isDirect ? Colors.green : Colors.orange).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isProxy ? 'PROXY' : isDirect ? 'DIRECT' : 'OTHER',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isProxy ? Colors.blue : isDirect ? Colors.green : Colors.orange,
                ),
              ),
            ),
            if (conn.packageName != null)
              Text(
                conn.packageName!,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('ID', conn.id),
                _DetailRow('Правило', conn.rule.isEmpty ? '—' : conn.rule),
                _DetailRow('Inbound', '${conn.inbound} (${conn.inboundType})'),
                _DetailRow('Outbound', '${conn.outbound} (${conn.outboundType})'),
                _DetailRow('Источник', conn.source),
                _DetailRow('Назначение', conn.destination),
                _DetailRow('Домен', conn.domain.isEmpty ? '—' : conn.domain),
                _DetailRow('Протокол', conn.protocol.isEmpty ? '—' : conn.protocol),
                _DetailRow('Пользователь', conn.user.isEmpty ? '—' : conn.user),
                _DetailRow('Открыто', conn.createdAt.toLocal().toString()),
                _DetailRow('Закрыто', conn.closedAt?.toLocal().toString() ?? 'активно'),
                _DetailRow('Трафик', '↑ ${_formatBytes(conn.uplinkTotalBytes)}  ↓ ${_formatBytes(conn.downlinkTotalBytes)}'),
                if (conn.packageName != null)
                  _DetailRow('Пакет', conn.packageName!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
