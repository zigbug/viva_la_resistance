import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../models/app_profile.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Only select the fields needed at the page scaffold level.
    // Individual sections use context.select to limit their own rebuild scope.
    final connected = context.select<AppState, bool>((s) => s.serviceState.isRunning);
    final coreVersion = context.select<AppState, String>((s) => s.coreVersion);
    final lastAlert = context.select<AppState, String?>((s) => s.lastAlert);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: kBg,
              titleSpacing: 20,
              title: const Text('Flutter Sing-box Client'),
              actions: [
                if (coreVersion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kCardAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v$coreVersion',
                          style: const TextStyle(
                              color: kTextSecondary,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Alert
                  if (lastAlert != null) ...[
                    _AlertBanner(
                        message: lastAlert,
                        onDismiss: context.read<AppState>().clearAlert),
                    const SizedBox(height: 12),
                  ],

                  // Profile row
                  const _ProfileSection(),
                  const SizedBox(height: 12),

                  // Connection card
                  const _StatusCard(),

                  // Post-connection sections
                  if (connected) ...[
                    const SizedBox(height: 12),
                    const _TrafficCard(),
                    const SizedBox(height: 12),
                    const _StatsRow(),
                    const _ClashModeSection(),
                    const _GroupsSection(),
                    const SizedBox(height: 12),
                    const _ConnectionsSection(),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared primitives ─────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final Widget child;

  const _DashCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: kTextMuted,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Alert banner ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AlertBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kError.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kError, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: kTextPrimary, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: kTextMuted, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Profile section ───────────────────────────────────────────────────────────

class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    final profileName = context.select<AppState, String?>((s) {
      final id = s.selectedProfileId;
      if (id == null) return null;
      try {
        final p = s.profiles.firstWhere((p) => p.id == id);
        return p.name.isNotEmpty ? p.name : null;
      } catch (_) {
        return null;
      }
    });

    return GestureDetector(
      onTap: () => _openSheet(context),
      child: _DashCard(
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.folder_outlined, color: kAccent, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Profile'),
                  const SizedBox(height: 3),
                  Text(
                    profileName ?? 'No profile selected',
                    style: TextStyle(
                      color: profileName != null ? kTextPrimary : kTextMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final state = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(state: state),
    );
  }
}

// ── Profile bottom sheet ──────────────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  final AppState state;
  const _ProfileSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final profiles = state.profiles;
    final selectedId = state.selectedProfileId;
    final isConnected = state.serviceState.isRunning;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: kDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Profiles',
                  style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _AddProfileSheet(state: state),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: kAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: kAccent, size: 14),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: kAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: profiles.isEmpty
                ? const Center(
                    child: Text('No profiles yet',
                        style: TextStyle(color: kTextMuted, fontSize: 14)),
                  )
                : ListView.separated(
                    controller: scroll,
                    itemCount: profiles.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 20),
                    itemBuilder: (_, i) {
                      final p = profiles[i];
                      final isSelected = p.id == selectedId;
                      return ListTile(
                        onTap: () {
                          state.selectProfile(p.id);
                          Navigator.pop(ctx);
                        },
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? kAccent : kTextMuted,
                          size: 20,
                        ),
                        title: Text(p.name,
                            style: TextStyle(
                                color: isSelected ? kAccent : kTextPrimary,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                        subtitle: Text(
                          p.type == AppProfileType.remote ? 'Remote' : 'Local',
                          style:
                              const TextStyle(color: kTextMuted, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.type == AppProfileType.remote)
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: kTextMuted, size: 18),
                                onPressed: () =>
                                    state.updateRemoteProfile(p.id),
                                tooltip: 'Update',
                              ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  color: (isConnected && p.id == selectedId)
                                      ? kTextMuted.withValues(alpha: 0.3)
                                      : kTextMuted,
                                  size: 18),
                              onPressed: (isConnected && p.id == selectedId)
                                  ? null
                                  : () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) => _EditProfileSheet(
                                            state: state, profile: p),
                                      ),
                              tooltip: (isConnected && p.id == selectedId)
                                  ? 'Stop VPN to edit'
                                  : 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: kTextMuted, size: 18),
                              onPressed: () =>
                                  _confirmDelete(context, state, p),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext sheetContext, AppState state, AppProfile p) {
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text('Delete "${p.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog
              Navigator.pop(sheetContext); // close sheet
              state.deleteProfile(p.id);
            },
            child: const Text('Delete', style: TextStyle(color: kError)),
          ),
        ],
      ),
    );
  }
}

// ── Add profile sheet ─────────────────────────────────────────────────────────

class _AddProfileSheet extends StatefulWidget {
  final AppState state;
  const _AddProfileSheet({required this.state});

  @override
  State<_AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends State<_AddProfileSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _name = TextEditingController();
  final _content = TextEditingController();
  final _url = TextEditingController();
  bool _autoUpdate = false;
  int _intervalSeconds = 3600;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _content.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.54,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: kDivider, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Profile',
                    style: TextStyle(
                        color: kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabs,
              indicatorColor: kAccent,
              labelColor: kAccent,
              unselectedLabelColor: kTextMuted,
              dividerColor: kDivider,
              tabs: const [Tab(text: 'Local JSON'), Tab(text: 'Remote URL')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_buildLocalTab(), _buildRemoteTab()],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kError.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: kError, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: kError, fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _error = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: kError, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: kBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kBg),
                        )
                      : const Text('Add',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: 'My Profile'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            decoration: const InputDecoration(
              labelText: 'Config JSON',
              hintText: 'Paste Sing-box JSON config here',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.paste, size: 15),
                label: const Text('Paste', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: kTextSecondary),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) _content.text = d!.text!;
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.format_align_left, size: 15),
                label: const Text('Format', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: kTextSecondary),
                onPressed: _formatJson,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Name', hintText: 'My Profile'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Config URL',
              hintText: 'https://...',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            title: const Text('Auto-update',
                style: TextStyle(color: kTextPrimary, fontSize: 13)),
            value: _autoUpdate,
            onChanged: (v) => setState(() => _autoUpdate = v),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          if (_autoUpdate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Interval',
                    style: TextStyle(color: kTextSecondary, fontSize: 13)),
                const Spacer(),
                DropdownButton<int>(
                  value: _intervalSeconds,
                  underline: const SizedBox(),
                  dropdownColor: kCardAlt,
                  style: const TextStyle(color: kTextPrimary, fontSize: 13),
                  onChanged: (v) {
                    if (v != null) setState(() => _intervalSeconds = v);
                  },
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 sec')),
                    DropdownMenuItem(value: 60, child: Text('1 min')),
                    DropdownMenuItem(value: 300, child: Text('5 min')),
                    DropdownMenuItem(value: 1800, child: Text('30 min')),
                    DropdownMenuItem(value: 3600, child: Text('1 hour')),
                    DropdownMenuItem(value: 21600, child: Text('6 hours')),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _formatJson() async {
    final raw = _content.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final formatted = await widget.state.formatConfig(raw);
      _content.text = formatted;
    } catch (e) {
      setState(() => _error = 'Format error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tabs.index == 0) {
        final content = _content.text.trim();
        if (content.isEmpty) {
          setState(() => _error = 'Config JSON is required');
          return;
        }
        await widget.state.addLocalProfile(name, content);
        final err = widget.state.configValidationError;
        if (err != null) {
          setState(() => _error = err);
          return;
        }
      } else {
        final url = _url.text.trim();
        if (url.isEmpty) {
          setState(() => _error = 'URL is required');
          return;
        }
        await widget.state.addRemoteProfile(name, url,
            autoUpdate: _autoUpdate,
            autoUpdateIntervalSeconds: _intervalSeconds);
        final err = widget.state.configValidationError;
        if (err != null) {
          setState(() => _error = err);
          return;
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Edit profile sheet ────────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final AppState state;
  final AppProfile profile;
  const _EditProfileSheet({required this.state, required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late final TextEditingController _url;
  late bool _autoUpdate;
  late int _intervalSeconds;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.name);
    _content = TextEditingController(text: p.content ?? '');
    _url = TextEditingController(text: p.remoteURL ?? '');
    _autoUpdate = p.autoUpdate;
    _intervalSeconds = p.autoUpdateIntervalSeconds;
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isRemote = widget.profile.type == AppProfileType.remote;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.75,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: kDivider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit ${isRemote ? 'Remote' : 'Local'} Profile',
                  style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    if (isRemote) ...[
                      TextField(
                        controller: _url,
                        decoration: const InputDecoration(
                            labelText: 'Config URL', hintText: 'https://...'),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        title: const Text('Auto-update',
                            style:
                                TextStyle(color: kTextPrimary, fontSize: 13)),
                        value: _autoUpdate,
                        onChanged: (v) => setState(() => _autoUpdate = v),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      if (_autoUpdate) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Interval',
                                style: TextStyle(
                                    color: kTextSecondary, fontSize: 13)),
                            const Spacer(),
                            DropdownButton<int>(
                              value: _intervalSeconds,
                              underline: const SizedBox(),
                              dropdownColor: kCardAlt,
                              style: const TextStyle(
                                  color: kTextPrimary, fontSize: 13),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _intervalSeconds = v);
                                }
                              },
                              items: const [
                                DropdownMenuItem(
                                    value: 30, child: Text('30 sec')),
                                DropdownMenuItem(
                                    value: 60, child: Text('1 min')),
                                DropdownMenuItem(
                                    value: 300, child: Text('5 min')),
                                DropdownMenuItem(
                                    value: 1800, child: Text('30 min')),
                                DropdownMenuItem(
                                    value: 3600, child: Text('1 hour')),
                                DropdownMenuItem(
                                    value: 21600, child: Text('6 hours')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _content,
                        decoration: const InputDecoration(
                            labelText: 'Config JSON',
                            hintText: '{ ... }',
                            alignLabelWithHint: true),
                        maxLines: 8,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kError.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: kError, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style:
                                const TextStyle(color: kError, fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _error = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: kError, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: kBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kBg),
                        )
                      : const Text('Save',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.profile.type == AppProfileType.remote) {
        final url = _url.text.trim();
        if (url.isEmpty) {
          setState(() => _error = 'URL is required');
          return;
        }
        await widget.state.editRemoteProfile(widget.profile.id, name, url,
            autoUpdate: _autoUpdate,
            autoUpdateIntervalSeconds: _intervalSeconds);
      } else {
        final content = _content.text.trim();
        if (content.isEmpty) {
          setState(() => _error = 'Config JSON is required');
          return;
        }
        await widget.state.editLocalProfile(widget.profile.id, name, content);
      }
      final err = widget.state.configValidationError;
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatefulWidget {
  const _StatusCard();

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  DateTime? _connectedAt;
  Timer? _ticker;
  late ServiceState _lastKnownState;

  @override
  void initState() {
    super.initState();
    _lastKnownState = context.read<AppState>().serviceState;
    if (_lastKnownState.isRunning) _startTimer();
  }

  @override
  void didUpdateWidget(_StatusCard old) {
    super.didUpdateWidget(old);
    final current = context.read<AppState>().serviceState;
    if (_lastKnownState == current) return;
    if (!_lastKnownState.isRunning && current.isRunning) {
      _startTimer();
    } else if (_lastKnownState.isRunning && !current.isRunning) {
      _stopTimer();
    }
    _lastKnownState = current;
  }

  void _startTimer() {
    _connectedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    _connectedAt = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  String _formatUptime() {
    if (_connectedAt == null) return '00:00:00';
    final d = DateTime.now().difference(_connectedAt!);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.select<AppState, ServiceState>((s) => s.serviceState);
    final isConnected = svc.isRunning;
    final isTransitioning = svc.isTransitioning;

    final statusColor = isConnected
        ? kSuccess
        : isTransitioning
            ? kWarning
            : kTextMuted;
    final statusLabel = switch (svc) {
      ServiceState.started => 'CONNECTED',
      ServiceState.starting => 'CONNECTING',
      ServiceState.stopping => 'DISCONNECTING',
      ServiceState.stopped => 'DISCONNECTED',
    };

    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (isConnected)
                Text(
                  _formatUptime(),
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (isConnected)
                IconButton(
                  icon: const Icon(Icons.refresh, color: kTextMuted, size: 20),
                  tooltip: 'Reload Config',
                  onPressed: () => context.read<AppState>().reloadConfig(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _ConnectButton(),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton();

  @override
  Widget build(BuildContext context) {
    final svc = context.select<AppState, ServiceState>((s) => s.serviceState);
    final hasProfile = context.select<AppState, bool>((s) => s.selectedProfileId != null);
    final isConnected = svc.isRunning;
    final isTransitioning = svc.isTransitioning;

    if (isTransitioning) {
      return const _ButtonShell(
        color: kCardAlt,
        borderColor: kDivider,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: kAccent),
        ),
      );
    }

    if (isConnected) {
      return _ButtonShell(
        color: kError.withValues(alpha: 0.1),
        borderColor: kError.withValues(alpha: 0.35),
        onTap: context.read<AppState>().toggleService,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new, color: kError, size: 16),
            SizedBox(width: 8),
            Text('DISCONNECT',
                style: TextStyle(
                    color: kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ],
        ),
      );
    }

    return _ButtonShell(
      color: hasProfile ? kAccent : kAccent.withValues(alpha: 0.25),
      onTap: hasProfile ? context.read<AppState>().toggleService : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.power_settings_new,
              color: hasProfile ? kBg : kBg.withValues(alpha: 0.4), size: 16),
          const SizedBox(width: 8),
          Text(
            'CONNECT',
            style: TextStyle(
              color: hasProfile ? kBg : kBg.withValues(alpha: 0.4),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonShell extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _ButtonShell({
    required this.child,
    required this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Traffic card ──────────────────────────────────────────────────────────────

class _TrafficCard extends StatelessWidget {
  const _TrafficCard();

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AppState, TrafficStats>((s) => s.trafficStats);
    return _DashCard(
      child: Row(
        children: [
          Expanded(
            child: _TrafficCol(
              icon: Icons.arrow_downward_rounded,
              label: 'Download',
              speed: formatSpeed(stats.downlinkBps),
              total: formatBytes(stats.downlinkTotalBytes),
              color: kAccent,
            ),
          ),
          Container(width: 1, height: 36, color: kDivider),
          Expanded(
            child: _TrafficCol(
              icon: Icons.arrow_upward_rounded,
              label: 'Upload',
              speed: formatSpeed(stats.uplinkBps),
              total: formatBytes(stats.uplinkTotalBytes),
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficCol extends StatelessWidget {
  final IconData icon;
  final String label;
  final String speed;
  final String total;
  final Color color;

  const _TrafficCol({
    required this.icon,
    required this.label,
    required this.speed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            _Label(label),
          ],
        ),
        const SizedBox(height: 4),
        Text(speed,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
        Text(total,
            style: const TextStyle(
                color: kTextMuted, fontSize: 11, fontFamily: 'monospace')),
      ],
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final stats = context.select<AppState, TrafficStats>((s) => s.trafficStats);
    final activeConnections = context.select<AppState, int>(
        (s) => s.connections.where((c) => c.isActive).length);
    return Row(
      children: [
        Expanded(
            child: _StatChip(
                label: 'Memory', value: formatBytes(stats.memoryBytes))),
        const SizedBox(width: 8),
        Expanded(
            child: _StatChip(
                label: 'Connections', value: '$activeConnections')),
        const SizedBox(width: 8),
        Expanded(
            child:
                _StatChip(label: 'Goroutines', value: '${stats.goroutines}')),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Label(label),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

// ── Clash mode section (self-selecting) ───────────────────────────────────────

class _ClashModeSection extends StatelessWidget {
  const _ClashModeSection();

  @override
  Widget build(BuildContext context) {
    final modes = context.select<AppState, List<String>>((s) => s.clashModes);
    if (modes.isEmpty) return const SizedBox.shrink();
    final current = context.select<AppState, String>((s) => s.currentClashMode);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _ClashModeCard(
        modes: modes,
        current: current,
        onSelect: context.read<AppState>().setClashMode,
      ),
    );
  }
}

// ── Clash mode card ───────────────────────────────────────────────────────────

class _ClashModeCard extends StatelessWidget {
  final List<String> modes;
  final String current;
  final void Function(String) onSelect;

  const _ClashModeCard({
    required this.modes,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Clash Mode'),
          const SizedBox(height: 10),
          Row(
            children: modes
                .map((m) => Expanded(
                      child: Padding(
                        padding:
                            EdgeInsets.only(right: m != modes.last ? 6 : 0),
                        child: _ModeBtn(
                          label: m,
                          isSelected: m == current,
                          onTap: () => onSelect(m),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kAccent.withValues(alpha: 0.15) : kCardAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? kAccent.withValues(alpha: 0.5) : kDivider,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? kAccent : kTextSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Groups section ────────────────────────────────────────────────────────────

class _GroupsSection extends StatelessWidget {
  const _GroupsSection();

  @override
  Widget build(BuildContext context) {
    final groups = context.select<AppState, List<OutboundGroup>>((s) => s.groups);
    if (groups.isEmpty) return const SizedBox.shrink();
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Label('Groups'),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${groups.length}',
                  style: const TextStyle(
                      color: kAccent, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...groups.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GroupCard(
                  group: g,
                  onSelectOutbound: (tag) => state.selectOutbound(g.tag, tag),
                  onUrlTest: () => state.urlTest(g.tag),
                ),
              )),
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final OutboundGroup group;
  final void Function(String) onSelectOutbound;
  final VoidCallback onUrlTest;

  const _GroupCard({
    required this.group,
    required this.onSelectOutbound,
    required this.onUrlTest,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kCardAlt,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.hub_outlined,
                      color: kTextSecondary, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.tag,
                          style: const TextStyle(
                              color: kTextPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '${g.type} · ${g.items.length} nodes'
                        '${g.selected.isNotEmpty ? ' · ${g.selected}' : ''}',
                        style: const TextStyle(color: kTextMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (g.selectable) ...[
                  GestureDetector(
                    onTap: widget.onUrlTest,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child:
                          const Icon(Icons.speed, color: kTextMuted, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: kTextMuted,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            ...g.items.map((item) {
              final isSelected = item.tag == g.selected;
              return GestureDetector(
                onTap: g.selectable
                    ? () => widget.onSelectOutbound(item.tag)
                    : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: isSelected ? kAccent : kTextMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.tag,
                                style: TextStyle(
                                    color: isSelected ? kAccent : kTextPrimary,
                                    fontSize: 13)),
                            Text(item.type,
                                style: const TextStyle(
                                    color: kTextMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      if (item.hasLatency)
                        _LatencyBadge(ms: item.urlTestDelayMs),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _LatencyBadge extends StatelessWidget {
  final int ms;
  const _LatencyBadge({required this.ms});

  @override
  Widget build(BuildContext context) {
    final color = ms < 100
        ? kSuccess
        : ms < 300
            ? kWarning
            : kError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${ms}ms',
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Connections section ───────────────────────────────────────────────────────

class _ConnectionsSection extends StatelessWidget {
  const _ConnectionsSection();

  @override
  Widget build(BuildContext context) {
    final connections = context.select<AppState, List<ConnectionInfo>>((s) => s.connections);
    final state = context.read<AppState>();
    final active = connections.where((c) => c.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _Label('Connections'),
            const SizedBox(width: 6),
            if (active.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${active.length}',
                  style: const TextStyle(
                      color: kAccent, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            const Spacer(),
            if (active.isNotEmpty)
              GestureDetector(
                onTap: () => state.closeAllConnections().catchError((_) {}),
                child: const Text('Close all',
                    style: TextStyle(color: kTextMuted, fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDivider),
            ),
            child: const Center(
              child: Text('No active connections',
                  style: TextStyle(color: kTextMuted, fontSize: 13)),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kDivider),
            ),
            child: Column(
              children: active.asMap().entries.map((e) => _ConnRow(
                    conn: e.value,
                    isLast: e.key == active.length - 1,
                    onClose: () => state.closeConnection(e.value.id).catchError((_) {}),
                  )).toList(),
            ),
          ),
      ],
    );
  }
}

class _ConnRow extends StatelessWidget {
  final ConnectionInfo conn;
  final bool isLast;
  final VoidCallback? onClose;

  const _ConnRow({required this.conn, required this.isLast, this.onClose});

  @override
  Widget build(BuildContext context) {
    final host = conn.domain.isNotEmpty ? conn.domain : conn.destination;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                conn.network == 'tcp'
                    ? Icons.cable_outlined
                    : Icons.wifi_outlined,
                size: 14,
                color: kSuccess,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 12),
                    ),
                    Text(
                      '${conn.outbound} · ${conn.network.toUpperCase()} · '
                      '↑${formatBytes(conn.uplinkTotalBytes)} ↓${formatBytes(conn.downlinkTotalBytes)}',
                      style: const TextStyle(color: kTextMuted, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.close, size: 16, color: kTextMuted),
                  ),
                ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1),
          ),
      ],
    );
  }
}
