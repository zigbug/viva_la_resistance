import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import 'network_quality_page.dart';
import 'per_app_proxy_page.dart';
import 'stun_test_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AppState, ({
      bool connected,
      NetworkMode networkMode,
      bool killSwitch,
      bool allowBypass,
      bool systemProxyEnabled,
      String notifTitle,
      String notifChannel,
      bool showTraffic,
      bool showStop,
      bool perAppEnabled,
      String perAppMode,
      int perAppCount,
      bool memEnabled,
      int memMb,
      bool memKill,
    })>((a) => (
          connected: a.serviceState.isRunning,
          networkMode: a.networkMode,
          killSwitch: a.killSwitch,
          allowBypass: a.allowBypass,
          systemProxyEnabled: a.systemProxyEnabled,
          notifTitle: a.notificationTitle,
          notifChannel: a.notificationChannelName,
          showTraffic: a.showTrafficInNotification,
          showStop: a.showStopButtonInNotification,
          perAppEnabled: a.perAppProxyEnabled,
          perAppMode: a.perAppProxyMode.name,
          perAppCount: a.perAppProxyPackages.length,
          memEnabled: a.enableMemoryLimit,
          memMb: a.memoryLimitMb,
          memKill: a.killConnectionsOnLimit,
        ));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Divider(height: 1),

          // ── Service ───────────────────────────────────────────────────────
          const _SectionHeader('Service'),
          _SettingTile(
            title: 'Service Mode',
            subtitle: s.connected ? 'Stop service to change' : null,
            trailing: _ModeDropdown(
              value: s.networkMode,
              enabled: !s.connected,
              onChanged: (m) {
                if (m != null) context.read<AppState>().networkMode = m;
              },
            ),
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'Kill Switch',
            subtitle: s.networkMode != NetworkMode.vpn
                ? 'VPN mode only'
                : 'Block traffic when VPN disconnects',
            value: s.killSwitch,
            enabled: !s.connected && s.networkMode == NetworkMode.vpn,
            onChanged: (v) => context.read<AppState>().killSwitch = v,
            modeWarning: s.networkMode != NetworkMode.vpn,
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'Allow Bypass',
            subtitle: 'Allow apps to bypass the VPN tunnel',
            value: s.allowBypass,
            enabled: !s.connected && !s.killSwitch,
            onChanged: (v) => context.read<AppState>().allowBypass = v,
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'System Proxy',
            subtitle: s.networkMode != NetworkMode.vpn
                ? 'VPN mode only'
                : 'Route HTTP traffic via system proxy',
            value: s.systemProxyEnabled,
            enabled: !s.connected && s.networkMode == NetworkMode.vpn,
            onChanged: (v) =>
                context.read<AppState>().systemProxyEnabled = v,
            modeWarning: s.networkMode != NetworkMode.vpn,
          ),

          // ── Notification ──────────────────────────────────────────────────
          const _SectionHeader('Notification'),
          _SettingTile(
            title: 'Title',
            subtitle: s.notifTitle.isNotEmpty ? s.notifTitle : 'Singbox',
            onTap: s.connected
                ? null
                : () => _editText(
                      context,
                      label: 'Notification Title',
                      value: s.notifTitle,
                      onSave: (v) =>
                          context.read<AppState>().notificationTitle = v,
                    ),
            trailing: const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
          ),
          _DividerThin(),
          _SettingTile(
            title: 'Channel Name',
            subtitle: s.notifChannel.isNotEmpty
                ? s.notifChannel
                : 'Singbox Service',
            onTap: s.connected
                ? null
                : () => _editText(
                      context,
                      label: 'Channel Name',
                      value: s.notifChannel,
                      onSave: (v) => context
                          .read<AppState>()
                          .notificationChannelName = v,
                    ),
            trailing: const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'Live Traffic',
            subtitle: 'Show speeds in notification',
            value: s.showTraffic,
            enabled: !s.connected,
            onChanged: (v) =>
                context.read<AppState>().showTrafficInNotification = v,
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'Stop Button',
            subtitle: 'Show quick-stop in notification',
            value: s.showStop,
            enabled: !s.connected,
            onChanged: (v) =>
                context.read<AppState>().showStopButtonInNotification = v,
          ),

          // ── Memory Limit ──────────────────────────────────────────────────
          const _SectionHeader('Memory'),
          _SwitchTile(
            title: 'Memory Limit',
            subtitle: 'Apply a soft Go runtime memory cap',
            value: s.memEnabled,
            enabled: !s.connected,
            onChanged: (v) =>
                context.read<AppState>().enableMemoryLimit = v,
          ),
          _DividerThin(),
          _SettingTile(
            title: 'Limit',
            subtitle: s.memMb >= 1024 ? '1 GB' : '${s.memMb} MB',
            enabled: !s.connected && s.memEnabled,
            trailing: _MemDropdown(
              value: s.memMb,
              enabled: !s.connected && s.memEnabled,
              onChanged: (v) {
                if (v != null) context.read<AppState>().memoryLimitMb = v;
              },
            ),
          ),
          _DividerThin(),
          _SwitchTile(
            title: 'Kill Connections on Limit',
            subtitle: 'Drop connections when limit is reached',
            value: s.memKill,
            enabled: !s.connected && s.memEnabled,
            onChanged: (v) =>
                context.read<AppState>().killConnectionsOnLimit = v,
          ),

          // ── Advanced ──────────────────────────────────────────────────────
          const _SectionHeader('Advanced'),
          _NavTile(
            title: 'Per-App Proxy',
            subtitle: s.perAppEnabled
                ? '${s.perAppMode.toUpperCase()} · ${s.perAppCount} app(s)'
                : 'Disabled',
            icon: Icons.apps_outlined,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PerAppProxyPage())),
          ),

          // ── Network Testing ───────────────────────────────────────────────
          const _SectionHeader('Network Testing'),
          _NavTile(
            title: 'STUN Test',
            subtitle: 'Check NAT type and external IP',
            icon: Icons.network_check_outlined,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StunTestPage())),
          ),
          _DividerThin(),
          _NavTile(
            title: 'Network Quality',
            subtitle: 'Run a connectivity quality check',
            icon: Icons.speed_outlined,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NetworkQualityPage())),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _editText(
    BuildContext context, {
    required String label,
    required String value,
    required ValueChanged<String> onSave,
  }) {
    showDialog(
      context: context,
      builder: (_) => _EditDialog(label: label, value: value, onSave: onSave),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: kAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _DividerThin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: enabled ? kTextPrimary : kTextMuted,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool modeWarning;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.modeWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: enabled ? kTextPrimary : kTextMuted,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: modeWarning ? kWarning : kTextMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _NavTile({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          const TextStyle(color: kTextPrimary, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Dropdowns ─────────────────────────────────────────────────────────────────

class _ModeDropdown extends StatelessWidget {
  final NetworkMode value;
  final bool enabled;
  final ValueChanged<NetworkMode?> onChanged;

  const _ModeDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<NetworkMode>(
      value: value,
      underline: const SizedBox(),
      dropdownColor: kCardAlt,
      style: const TextStyle(color: kTextPrimary, fontSize: 13),
      iconEnabledColor: kTextMuted,
      iconDisabledColor: kTextMuted,
      onChanged: enabled ? onChanged : null,
      items: NetworkMode.values
          .map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.name.toUpperCase()),
              ))
          .toList(),
    );
  }
}

class _MemDropdown extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _MemDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: value,
      underline: const SizedBox(),
      dropdownColor: kCardAlt,
      style: const TextStyle(color: kTextPrimary, fontSize: 13),
      iconEnabledColor: kTextMuted,
      iconDisabledColor: kTextMuted,
      onChanged: enabled ? onChanged : null,
      items: const [50, 100, 200, 300, 500, 750, 1024]
          .map((mb) => DropdownMenuItem(
                value: mb,
                child: Text(mb >= 1024 ? '1 GB' : '$mb MB'),
              ))
          .toList(),
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditDialog extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onSave;

  const _EditDialog({
    required this.label,
    required this.value,
    required this.onSave,
  });

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _save(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kTextSecondary)),
        ),
        TextButton(
          onPressed: () => _save(context),
          child: const Text('Save', style: TextStyle(color: kAccent)),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    widget.onSave(_ctrl.text.trim());
    Navigator.pop(context);
  }
}
