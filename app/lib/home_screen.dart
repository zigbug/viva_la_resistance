import 'package:flutter/material.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

import 'app_config.dart';
import 'config_builder.dart';
import 'log_viewer.dart';
import 'vpn_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final VpnController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VpnController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.init();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Viva la Resistance'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Журнал и соединения',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LogViewerScreen(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.article_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final state = controller.state;
          final connected = state == ServiceState.started;
          final transitioning = state.isTransitioning || controller.busy;
          final statusColor = switch (state) {
            ServiceState.started => const Color(0xFF4CAF50),
            ServiceState.starting || ServiceState.stopping => Colors.amber,
            ServiceState.stopped => Colors.grey,
          };

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _StatusCard(
                        icon: connected ? Icons.shield : Icons.shield_outlined,
                        color: statusColor,
                        status: _statusLabel(state),
                        subtitle: controller.isRunning
                            ? _trafficLabel(controller.traffic)
                            : _offSubtitle(controller.mode),
                        active: connected,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: transitioning ? null : controller.toggle,
                          icon: transitioning
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : Icon(
                                  connected
                                      ? Icons.power_settings_new
                                      : Icons.play_arrow_rounded,
                                ),
                          label: Text(
                            transitioning
                                ? 'Подождите…'
                                : connected
                                ? 'Отключить'
                                : 'Подключить',
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                      if (controller.error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorCard(
                          message: controller.error!,
                          onDismiss: controller.clearError,
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AdvancedCard(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _statusLabel(ServiceState state) => switch (state) {
    ServiceState.stopped => 'Отключено',
    ServiceState.starting => 'Подключение…',
    ServiceState.started => 'Подключено',
    ServiceState.stopping => 'Отключение…',
  };

  static String _offSubtitle(TunnelMode mode) => switch (mode) {
    TunnelMode.domains => 'Выборочно по доменам',
    TunnelMode.apps => 'Только выбранные приложения',
  };

  static String _trafficLabel(TrafficStats stats) {
    return '↓ ${_formatBits(stats.downlinkBps)}   ↑ ${_formatBits(stats.uplinkBps)}';
  }

  static String _formatBits(int bitsPerSecond) {
    if (bitsPerSecond <= 0) {
      return '0 Кбит/с';
    }
    if (bitsPerSecond < 1000 * 1000) {
      return '${(bitsPerSecond / 1000).toStringAsFixed(1)} Кбит/с';
    }
    return '${(bitsPerSecond / 1000 / 1000).toStringAsFixed(2)} Мбит/с';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.status,
    required this.subtitle,
    required this.active,
  });

  final IconData icon;
  final Color color;
  final String status;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.65) : theme.dividerColor,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: active ? 0.22 : 0.08),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 12),
          Text(
            status,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: scheme.onErrorContainer),
            tooltip: 'Скрыть',
          ),
        ],
      ),
    );
  }
}

class _AdvancedCard extends StatelessWidget {
  const _AdvancedCard({required this.controller});

  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEdit = controller.canEdit;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: const Text('Расширенные'),
        subtitle: Text(
          canEdit
              ? 'Режим и сервисы'
              : 'Остановите VPN, чтобы изменить настройки',
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Режим', style: theme.textTheme.titleSmall),
              const Spacer(),
              SegmentedButton<TunnelMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in TunnelMode.values)
                    ButtonSegment<TunnelMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                ],
                selected: {controller.mode},
                onSelectionChanged: canEdit
                    ? (selection) {
                        if (selection.isNotEmpty) {
                          controller.setMode(selection.first);
                        }
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            controller.mode.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 28),
          Text('Сервисы', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final service in ServiceId.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.services.contains(service),
              onChanged: canEdit
                  ? (value) => _setService(service, value)
                  : null,
              title: Text(service.label),
              secondary: Icon(
                service == ServiceId.youtube
                    ? Icons.smart_display_outlined
                    : Icons.camera_alt_outlined,
              ),
            ),
          const Divider(height: 28),
          _InfoRow(label: 'Сервер', value: controller.config.serverName),
          const SizedBox(height: 6),
          _InfoRow(label: 'Порт', value: controller.config.port.toString()),
          if (controller.coreVersion != null) ...[
            const SizedBox(height: 6),
            _InfoRow(label: 'Ядро sing-box', value: controller.coreVersion!),
          ],
        ],
      ),
    );
  }

  void _setService(ServiceId service, bool value) {
    if (!value && controller.services.length == 1) {
      return;
    }
    controller.setServiceEnabled(service, value);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
