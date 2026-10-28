import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

// ── Sort options ──────────────────────────────────────────────────────────────

enum _SortBy { name, packageName, installTime }

// ── Page ──────────────────────────────────────────────────────────────────────

class PerAppProxyPage extends StatefulWidget {
  const PerAppProxyPage({super.key});

  @override
  State<PerAppProxyPage> createState() => _PerAppProxyPageState();
}

class _PerAppProxyPageState extends State<PerAppProxyPage> {
  List<AppInfo> _allApps = [];
  bool _loading = false;
  String? _loadError;

  // UI-local state (not persisted)
  _SortBy _sortBy = _SortBy.name;
  bool _sortReverse = false;
  bool _excludeSystemApps = true;

  AppState? _appState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _appState = context.read<AppState>();
      if (_appState!.perAppProxyEnabled) _loadApps();
      _appState!.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    _appState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (_appState?.perAppProxyEnabled == true && _allApps.isEmpty && !_loading) {
      _loadApps();
    }
  }

  Future<void> _loadApps() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final apps = await InstalledApps.getInstalledApps(_excludeSystemApps, true);
      if (mounted) setState(() { _allApps = apps; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  List<AppInfo> _filtered() {
    var list = List.of(_allApps);
    list.sort((a, b) {
      final cmp = switch (_sortBy) {
        _SortBy.name        => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _SortBy.packageName => a.packageName.compareTo(b.packageName),
        _SortBy.installTime => a.installedTimestamp.compareTo(b.installedTimestamp),
      };
      return _sortReverse ? -cmp : cmp;
    });
    return list;
  }

  Future<void> _reloadWithSystemFilter(bool exclude) async {
    _excludeSystemApps = exclude;
    _allApps = [];
    await _loadApps();
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        sortBy: _sortBy,
        sortReverse: _sortReverse,
        excludeSystemApps: _excludeSystemApps,
        onSortBy: (v) => setState(() => _sortBy = v),
        onSortReverse: (v) => setState(() => _sortReverse = v),
        onExcludeSystem: (v) => _reloadWithSystemFilter(v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.select<AppState, bool>((s) => s.serviceState.isRunning);
    final perAppEnabled = context.select<AppState, bool>((s) => s.perAppProxyEnabled);
    final perAppMode = context.select<AppState, PerAppProxyMode>((s) => s.perAppProxyMode);
    final selected = context.select<AppState, Set<String>>((s) => s.perAppProxyPackages);
    final filtered = _filtered();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Per-App Proxy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => showSearch(
              context: context,
              delegate: _AppSearchDelegate(
                apps: _allApps,
                state: context.read<AppState>(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Sort & Filter',
            onPressed: _showFilterMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Enable toggle ──────────────────────────────────────────────
          SwitchListTile(
            title: const Text('Enable Per-App Proxy'),
            subtitle: Text(
              connected ? 'Reconnect to apply changes' : 'Applies at next connection',
            ),
            value: perAppEnabled,
            onChanged: connected ? null : (v) => context.read<AppState>().perAppProxyEnabled = v,
          ),

          // ── Mode selector ──────────────────────────────────────────────
          if (perAppEnabled)
            _ModeSelector(
              mode: perAppMode,
              enabled: !connected,
              onChanged: (v) => context.read<AppState>().perAppProxyMode = v,
            ),

          // ── Info banner ────────────────────────────────────────────────
          if (perAppEnabled)
            _InfoBanner(mode: perAppMode, count: selected.length),

          const Divider(height: 1),

          // ── App list ───────────────────────────────────────────────────
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_loadError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('Failed to load apps',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _loadApps, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Expanded(child: Center(child: Text('No apps found')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _AppTile(
                  app: filtered[i],
                  isSelected: selected.contains(filtered[i].packageName),
                  enabled: perAppEnabled && !connected,
                  onToggle: (_) =>
                      context.read<AppState>().togglePerAppPackage(filtered[i].packageName),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mode selector ─────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final PerAppProxyMode mode;
  final bool enabled;
  final ValueChanged<PerAppProxyMode> onChanged;

  const _ModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text('Proxy Mode', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 16),
          SegmentedButton<PerAppProxyMode>(
            segments: const [
              ButtonSegment(
                value: PerAppProxyMode.exclude,
                label: Text('Exclude'),
                icon: Icon(Icons.block),
              ),
              ButtonSegment(
                value: PerAppProxyMode.include,
                label: Text('Include'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {mode},
            onSelectionChanged: enabled
                ? (s) { if (s.isNotEmpty) onChanged(s.first); }
                : null,
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final PerAppProxyMode mode;
  final int count;
  const _InfoBanner({required this.mode, required this.count});

  @override
  Widget build(BuildContext context) {
    final verb = mode == PerAppProxyMode.exclude ? 'excluded from' : 'included in';
    final label = count == 0
        ? 'No apps selected'
        : '$count app${count == 1 ? '' : 's'} $verb VPN';
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

// ── App tile ──────────────────────────────────────────────────────────────────

class _AppTile extends StatelessWidget {
  final AppInfo app;
  final bool isSelected;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: app.icon != null
            ? Image.memory(app.icon!, width: 40, height: 40)
            : const Icon(Icons.android, size: 40),
      ),
      title: Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: Switch(
        value: isSelected,
        onChanged: enabled ? onToggle : null,
      ),
      onTap: enabled ? () => onToggle(!isSelected) : null,
    );
  }
}

// ── Sort & Filter bottom sheet ────────────────────────────────────────────────

class _FilterSheet extends StatelessWidget {
  final _SortBy sortBy;
  final bool sortReverse;
  final bool excludeSystemApps;
  final ValueChanged<_SortBy> onSortBy;
  final ValueChanged<bool> onSortReverse;
  final ValueChanged<bool> onExcludeSystem;

  const _FilterSheet({
    required this.sortBy,
    required this.sortReverse,
    required this.excludeSystemApps,
    required this.onSortBy,
    required this.onSortReverse,
    required this.onExcludeSystem,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetSection(
              icon: Icons.sort,
              title: 'Sort By',
              children: [
                RadioGroup<_SortBy>(
                  groupValue: sortBy,
                  onChanged: (v) { if (v != null) onSortBy(v); },
                  child: Column(
                    children: _SortBy.values.map((s) => RadioListTile<_SortBy>(
                      dense: true,
                      title: Text(_sortLabel(s)),
                      value: s,
                    )).toList(),
                  ),
                ),
                CheckboxListTile(
                  dense: true,
                  title: const Text('Reverse'),
                  value: sortReverse,
                  onChanged: (v) => onSortReverse(v ?? false),
                ),
              ],
            ),
            _SheetSection(
              icon: Icons.filter_alt_outlined,
              title: 'Filter',
              children: [
                CheckboxListTile(
                  dense: true,
                  title: const Text('Hide system apps'),
                  value: excludeSystemApps,
                  onChanged: (v) => onExcludeSystem(v ?? false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sortLabel(_SortBy s) => switch (s) {
        _SortBy.name        => 'By name',
        _SortBy.packageName => 'By package name',
        _SortBy.installTime => 'By install time',
      };
}

class _SheetSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SheetSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

// ── Search delegate ───────────────────────────────────────────────────────────

class _AppSearchDelegate extends SearchDelegate<void> {
  final List<AppInfo> apps;
  final AppState state;

  _AppSearchDelegate({required this.apps, required this.state});

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? apps
        : apps
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.packageName.toLowerCase().contains(q))
            .toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No apps found'));
    }

    final selected = context.select<AppState, Set<String>>((s) => s.perAppProxyPackages);
    final enabled = context.select<AppState, bool>(
        (s) => s.perAppProxyEnabled && !s.serviceState.isRunning);

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _AppTile(
        app: filtered[i],
        isSelected: selected.contains(filtered[i].packageName),
        enabled: enabled,
        onToggle: (_) => state.togglePerAppPackage(filtered[i].packageName),
      ),
    );
  }
}
