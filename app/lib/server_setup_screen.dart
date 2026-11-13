import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vpn_controller.dart';
import 'vps_setup_guide_screen.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({
    super.key,
    required this.controller,
    required this.requiredSetup,
    this.onConfigured,
  });

  final VpnController controller;
  final bool requiredSetup;
  final VoidCallback? onConfigured;

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _port;
  late final TextEditingController _uuid;
  late final TextEditingController _flow;
  late final TextEditingController _serverName;
  late final TextEditingController _publicKey;
  late final TextEditingController _shortId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.controller.config;
    _address = TextEditingController(text: c.address);
    _port = TextEditingController(text: c.port.toString());
    _uuid = TextEditingController(text: c.uuid);
    _flow = TextEditingController(text: c.flow);
    _serverName = TextEditingController(text: c.serverName);
    _publicKey = TextEditingController(text: c.realityPublicKey);
    _shortId = TextEditingController(text: c.realityShortId);
  }

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    _uuid.dispose();
    _flow.dispose();
    _serverName.dispose();
    _publicKey.dispose();
    _shortId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final port = int.tryParse(_port.text.trim());
      final draft = widget.controller.config.copyWithServer(
        address: _address.text.trim(),
        port: port ?? widget.controller.config.port,
        uuid: _uuid.text.trim(),
        flow: _flow.text.trim(),
        serverName: _serverName.text.trim(),
        realityPublicKey: _publicKey.text.trim(),
        realityShortId: _shortId.text.trim(),
      );
      final err = draft.serverValidationError();
      if (err != null) {
        setState(() => _error = err);
        return;
      }
      await draft.saveServer(widget.controller.paths.base);
      widget.controller.updateConfig(draft);
      if (!mounted) return;
      if (widget.requiredSetup) {
        widget.onConfigured?.call();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const VpsSetupGuideScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Инструкция по настройке VPS'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.requiredSetup) ...[
                    Icon(Icons.dns_outlined,
                        size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Настройка сервера',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Укажите параметры вашего VPS (VLESS + Reality). '
                      'Эти данные хранятся только на устройстве.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Параметры VPS (VLESS + Reality). Изменения применятся при следующем подключении.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  _field(_address, 'Адрес сервера',
                      hint: 'IP или домен VPS',
                      icon: Icons.language,
                      keyboard: TextInputType.url),
                  const SizedBox(height: 12),
                  _field(_port, 'Порт',
                      hint: '443',
                      icon: Icons.numbers,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly]),
                  const SizedBox(height: 12),
                  _field(_uuid, 'UUID',
                      hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                      icon: Icons.fingerprint,
                      keyboard: TextInputType.text),
                  const SizedBox(height: 12),
                  _field(_flow, 'Flow',
                      hint: 'xtls-rprx-vision',
                      icon: Icons.route_outlined),
                  const SizedBox(height: 12),
                  _field(_serverName, 'SNI / server_name',
                      hint: 'example.com',
                      icon: Icons.badge_outlined,
                      keyboard: TextInputType.url),
                  const SizedBox(height: 12),
                  _field(_publicKey, 'Reality public key',
                      hint: 'публичный ключ',
                      icon: Icons.vpn_key_outlined),
                  const SizedBox(height: 12),
                  _field(_shortId, 'Reality short id',
                      hint: 'short id',
                      icon: Icons.tag),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style:
                            TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Сохранить'),
                  ),
                  if (!widget.requiredSetup) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Отмена'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.requiredSetup) {
      return Scaffold(
        appBar: AppBar(title: const Text('Viva la Resistance')),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Сервер')),
      body: body,
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    IconData? icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }
}
