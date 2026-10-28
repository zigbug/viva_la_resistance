import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import '../app_state.dart';

const _defaultServer = 'stun.voipgate.com:3478';

class StunTestPage extends StatefulWidget {
  const StunTestPage({super.key});

  @override
  State<StunTestPage> createState() => _StunTestPageState();
}

class _StunTestPageState extends State<StunTestPage> {
  StreamSubscription<StunProgress>? _sub;
  StunProgress? _latest;
  bool _running = false;
  String? _error;
  String _server = _defaultServer;

  @override
  void dispose() {
    _sub?.cancel();
    if (_running) {
      context.read<AppState>().client.stopStunTest();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final client = context.read<AppState>().client;
    setState(() {
      _running = true;
      _error = null;
      _latest = null;
    });

    _sub?.cancel();
    _sub = client.stunProgressStream.listen(
      (p) {
        setState(() {
          _latest = p;
          if (!p.isRunning) _running = false;
        });
      },
      onError: (e) {
        setState(() {
          _error = e.toString();
          _running = false;
        });
      },
    );

    try {
      await client.startStunTest(_server);
    } catch (e) {
      _sub?.cancel();
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  Future<void> _stop() async {
    try {
      await context.read<AppState>().client.stopStunTest();
    } catch (_) {}
    _sub?.cancel();
    setState(() => _running = false);
  }

  void _editServer() {
    final ctrl = TextEditingController(text: _server);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('STUN Server'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'host:port',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _server = ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STUN Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _editServer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Server'),
                                Text(
                                  _server,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),

          if (_latest != null) ...[
            const SizedBox(height: 4),
            _ResultCard(progress: _latest!),
            const SizedBox(height: 8),
          ],

          // Start / Cancel button
          if (_running)
            Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel Test'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.network_check),
                label: const Text('Start Test'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final StunProgress progress;
  const _ResultCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              progress.isRunning ? 'Live Results' : 'Final Results',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            const Divider(height: 20),
            _PhaseRow(
              label: 'External Address',
              value: progress.externalAddress.isEmpty
                  ? null
                  : progress.externalAddress,
              active: progress.isRunning &&
                  progress.phase == StunPhase.binding,
            ),
            const Divider(height: 16),
            _PhaseRow(
              label: 'Latency',
              value:
                  progress.latencyMs > 0 ? '${progress.latencyMs} ms' : null,
              active: progress.isRunning &&
                  progress.phase == StunPhase.binding,
            ),
            const Divider(height: 16),
            _PhaseRow(
              label: 'NAT Mapping',
              value:
                  progress.natMapping.isEmpty ? null : progress.natMapping,
              active: progress.isRunning &&
                  progress.phase == StunPhase.natMapping,
            ),
            const Divider(height: 16),
            _PhaseRow(
              label: 'NAT Filtering',
              value: progress.natFiltering.isEmpty
                  ? null
                  : progress.natFiltering,
              active: progress.isRunning &&
                  progress.phase == StunPhase.natFiltering,
            ),
            if (progress.phase == StunPhase.done && !progress.natTypeSupported)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'NAT type detection not supported by this server.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool active;

  const _PhaseRow({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        if (active && value == null)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (value != null)
          Text(value!, style: const TextStyle(fontWeight: FontWeight.w600))
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
