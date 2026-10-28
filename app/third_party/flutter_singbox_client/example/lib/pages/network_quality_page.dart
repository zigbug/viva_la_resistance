import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../utils/format.dart';

class NetworkQualityPage extends StatefulWidget {
  const NetworkQualityPage({super.key});

  @override
  State<NetworkQualityPage> createState() => _NetworkQualityPageState();
}

class _NetworkQualityPageState extends State<NetworkQualityPage> {
  StreamSubscription<NetworkQualityProgress>? _sub;
  NetworkQualityProgress? _latest;
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    if (_running) {
      context.read<AppState>().client.stopNetworkQualityTest();
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
    _sub = client.networkQualityProgressStream.listen(
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
      await client.startNetworkQualityTest();
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
      await context.read<AppState>().client.stopNetworkQualityTest();
    } catch (_) {}
    _sub?.cancel();
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: const Text('Network Quality')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            _ErrorBanner(
              message: _error!,
              onClose: () => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
          ],
          _ResultCard(progress: _latest, running: _running),
          const SizedBox(height: 16),
          _ActionSection(running: _running, onStart: _start, onStop: _stop),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClose;
  const _ErrorBanner({required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kError.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kError.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: kError, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: kError, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: kError, size: 16),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final NetworkQualityProgress? progress;
  final bool running;
  const _ResultCard({required this.progress, required this.running});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final hasData = p != null;
    final label = running
        ? 'Measuring…'
        : hasData
            ? 'Test Complete'
            : 'Ready';

    final labelColor = running
        ? kAccent
        : hasData
            ? kSuccess
            : kTextMuted;

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: labelColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              if (running) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kAccent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: kSuccess,
                  label: 'Download',
                  value: hasData ? formatSpeed(p.downloadCapacityBps) : '--',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: kAccent,
                  label: 'Upload',
                  value: hasData ? formatSpeed(p.uploadCapacityBps) : '--',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.timer_outlined,
                  iconColor: kWarning,
                  label: 'Latency',
                  value: hasData ? '${p.idleLatencyMs} ms' : '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: kDivider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.swap_vert_rounded,
                  iconColor: kTextSecondary,
                  label: 'Download RPM',
                  value: hasData ? '${p.downloadRPM}' : '--',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.swap_vert_rounded,
                  iconColor: kTextSecondary,
                  label: 'Upload RPM',
                  value: hasData ? '${p.uploadRPM}' : '--',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  final bool running;
  final VoidCallback onStart;
  final VoidCallback onStop;
  const _ActionSection(
      {required this.running, required this.onStart, required this.onStop});

  @override
  Widget build(BuildContext context) {
    if (running) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              backgroundColor: kDivider,
              color: kAccent,
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Test runs for up to 30 seconds. Values update live.',
            style: TextStyle(color: kTextMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Cancel Test'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kError,
                side: const BorderSide(color: kError),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Start Test'),
        style: FilledButton.styleFrom(
          backgroundColor: kAccent,
          foregroundColor: kBg,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
