import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tabIndex = 0;
  LogLevel? _filter;
  LogLevel? _faultFilter;
  final _scroll = ScrollController();
  final _faultScroll = ScrollController();
  bool _autoScroll = true;

  static const _filterEntries = <(String, LogLevel?)>[
    ('All',   null),
    ('Trace', LogLevel.trace),
    ('Debug', LogLevel.debug),
    ('Info',  LogLevel.info),
    ('Warn',  LogLevel.warn),
    ('Error', LogLevel.error),
    ('Fatal', LogLevel.fatal),
    ('Panic', LogLevel.panic),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    _faultScroll.dispose();
    super.dispose();
  }

  List<LogEntry> _filtered(List<LogEntry> logs, LogLevel? filter) =>
      filter == null ? logs : logs.where((e) => e.level == filter).toList();

  void _scrollToBottom(ScrollController sc) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (sc.hasClients) sc.jumpTo(sc.position.maxScrollExtent);
    });
  }

  String _filterLabel(LogLevel? f) =>
      _filterEntries.firstWhere((e) => e.$2 == f).$1;

  bool get _onLogsTab => _tabIndex == 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final logs = List<LogEntry>.unmodifiable(state.logs);
    final faults = List<LogEntry>.unmodifiable(state.faultEntries);
    final filtered = _filtered(logs, _filter);
    final filteredFaults = _filtered(faults, _faultFilter);

    final currentFilter = _onLogsTab ? _filter : _faultFilter;
    final currentList = _onLogsTab ? logs : faults;
    final currentFiltered = _onLogsTab ? filtered : filteredFaults;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Row(
          children: [
            Text(_onLogsTab ? 'Logs' : 'Faults',
                style: TextStyle(
                    color: currentList.isEmpty ? kTextMuted : kTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            _FilterDropdown(
              label: _filterLabel(currentFilter),
              entries: _filterEntries,
              selected: currentFilter,
              onChanged: (v) => setState(
                  () => _onLogsTab ? _filter = v : _faultFilter = v),
            ),
          ],
        ),
        actions: [
          if (_onLogsTab)
            IconButton(
              icon: Icon(
                _autoScroll
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                size: 21,
                color: _autoScroll ? kAccent : kTextMuted,
              ),
              tooltip:
                  _autoScroll ? 'Pause auto-scroll' : 'Resume auto-scroll',
              onPressed: () => setState(() => _autoScroll = !_autoScroll),
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 19),
            tooltip: 'Copy all',
            onPressed: currentFiltered.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(
                        text: currentFiltered
                            .map((e) => _logLine(e))
                            .join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_remove, size: 21),
            tooltip: 'Clear',
            onPressed: currentList.isEmpty
                ? null
                : () {
                    if (_onLogsTab) {
                      context.read<AppState>().clearLogs();
                    } else {
                      context.read<AppState>().clearFaults();
                    }
                  },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          onTap: (i) => setState(() => _tabIndex = i),
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: kTextMuted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          dividerColor: kDivider,
          tabs: [
            Tab(text: 'Logs (${logs.length})'),
            Tab(text: 'Faults (${faults.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LogTabBody(
            logs: filtered,
            allLogs: logs,
            scroll: _scroll,
            autoScroll: _autoScroll,
            onScrollToBottom: () => _scrollToBottom(_scroll),
          ),
          _LogTabBody(
            logs: filteredFaults,
            allLogs: faults,
            scroll: _faultScroll,
            autoScroll: false,
            onScrollToBottom: () => _scrollToBottom(_faultScroll),
          ),
        ],
      ),
    );
  }

  String _logLine(LogEntry e) {
    final h = e.time.hour.toString().padLeft(2, '0');
    final m = e.time.minute.toString().padLeft(2, '0');
    final s = e.time.second.toString().padLeft(2, '0');
    return '$h:$m:$s [${e.level.name.toUpperCase()}] ${e.message}';
  }
}

// ── Tab body ──────────────────────────────────────────────────────────────────

class _LogTabBody extends StatelessWidget {
  final List<LogEntry> logs;
  final List<LogEntry> allLogs;
  final ScrollController scroll;
  final bool autoScroll;
  final VoidCallback onScrollToBottom;

  const _LogTabBody({
    required this.logs,
    required this.allLogs,
    required this.scroll,
    required this.autoScroll,
    required this.onScrollToBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    allLogs.isEmpty ? 'Nothing here yet' : 'No matching entries',
                    style:
                        const TextStyle(color: kTextMuted, fontSize: 13),
                  ),
                )
              : _LogList(
                  logs: logs,
                  scroll: scroll,
                  autoScroll: autoScroll,
                  onScrollToBottom: onScrollToBottom,
                ),
        ),
      ],
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String label;
  final List<(String, LogLevel?)> entries;
  final LogLevel? selected;
  final ValueChanged<LogLevel?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.entries,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final result = await showMenu<LogLevel?>(
          context: context,
          color: kCardAlt,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + box.size.height,
            offset.dx + 120,
            0,
          ),
          items: entries
              .map((e) => PopupMenuItem<LogLevel?>(
                    value: e.$2,
                    child: Text(
                      e.$1,
                      style: TextStyle(
                        color: e.$2 == selected ? kAccent : kTextPrimary,
                        fontSize: 13,
                        fontWeight: e.$2 == selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ))
              .toList(),
        );
        if (result != null || selected != null) {
          onChanged(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected != null ? kAccent.withValues(alpha: 0.12) : kCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected != null
                ? kAccent.withValues(alpha: 0.4)
                : kDivider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected != null ? kAccent : kTextSecondary,
                fontSize: 12,
                fontWeight:
                    selected != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 16,
                color: selected != null ? kAccent : kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Log list ──────────────────────────────────────────────────────────────────

class _LogList extends StatefulWidget {
  final List<LogEntry> logs;
  final ScrollController scroll;
  final bool autoScroll;
  final VoidCallback onScrollToBottom;

  const _LogList({
    required this.logs,
    required this.scroll,
    required this.autoScroll,
    required this.onScrollToBottom,
  });

  @override
  State<_LogList> createState() => _LogListState();
}

class _LogListState extends State<_LogList> {
  @override
  void didUpdateWidget(_LogList old) {
    super.didUpdateWidget(old);
    if (widget.autoScroll && widget.logs.length != old.logs.length) {
      widget.onScrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView.builder(
        controller: widget.scroll,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: widget.logs.length,
        itemBuilder: (_, i) => _LogRow(entry: widget.logs[i]),
      ),
    );
  }
}

// ── Log row ───────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  static const _levelColors = {
    LogLevel.trace: kTextMuted,
    LogLevel.debug: Color(0xFF64748B),
    LogLevel.info: kAccent,
    LogLevel.warn: kWarning,
    LogLevel.error: kError,
    LogLevel.fatal: Color(0xFFA855F7),
    LogLevel.panic: Color(0xFFA855F7),
  };

  @override
  Widget build(BuildContext context) {
    final color = _levelColors[entry.level] ?? kTextMuted;
    final h = entry.time.hour.toString().padLeft(2, '0');
    final m = entry.time.minute.toString().padLeft(2, '0');
    final s = entry.time.second.toString().padLeft(2, '0');
    final levelStr =
        entry.level.name.toUpperCase().padRight(5).substring(0, 5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$h:$m:$s',
            style: const TextStyle(
              color: kTextMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            levelStr,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(
                color: entry.level == LogLevel.error ||
                        entry.level == LogLevel.fatal
                    ? kError
                    : kTextPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
