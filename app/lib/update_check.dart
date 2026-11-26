import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:update_from_server/update_from_server.dart';

Future<void> checkForAppUpdate(
  BuildContext context, {
  bool manual = false,
}) async {
  final client = OtaClient(
    baseUrl: 'https://updates.905911.ru:8450',
    appKey: 'viva_la_resistance',
  );
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final update = await client.check(
      platform: _updatePlatform(),
      channel: 'stable',
      arch: 'universal',
      currentVersion: packageInfo.version,
      currentBuildNumber: int.tryParse(packageInfo.buildNumber),
    );
    if (update == null) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Установлена последняя версия')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final accepted = await _showUpdateDialog(context, update);
    if (accepted != true || !context.mounted) return;
    await _downloadAndInstallUpdate(context, update);
  } catch (e, st) {
    debugPrint('Update check failed: $e');
    debugPrint('$st');
    if (manual && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось проверить обновления: $e')),
      );
    }
  } finally {
    client.close();
  }
}

String _updatePlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'android';
}

Future<bool?> _showUpdateDialog(BuildContext context, UpdateInfo update) {
  final notes = update.releaseNotes.trim();
  return showDialog<bool>(
    context: context,
    barrierDismissible: !update.mandatory,
    builder: (ctx) => PopScope(
      canPop: !update.mandatory,
      child: AlertDialog(
        title: Text(
          update.mandatory ? 'Требуется обновление' : 'Доступно обновление',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${update.name.isNotEmpty ? update.name : update.app} ${update.version} (${update.buildNumber})',
              ),
              if (update.size > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Размер: ${_formatBytes(update.size)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Что нового:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(notes),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.mandatory)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Позже'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Установить'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _downloadAndInstallUpdate(
  BuildContext context,
  UpdateInfo update,
) async {
  final progress = ValueNotifier<double?>(null);
  final status = ValueNotifier<String>('Подготовка...');

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Загрузка обновления'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (ctx, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (ctx, text, _) => Text(text),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final downloader = UpdateDownloader();
    final path = await downloader.download(
      update,
      onProgress: (received, total) {
        if (total > 0) {
          progress.value = received / total;
          status.value =
              '${_formatBytes(received)} / ${_formatBytes(total)}';
        } else {
          progress.value = null;
          status.value = _formatBytes(received);
        }
      },
    );
    status.value = 'Запуск установки...';
    progress.value = null;
    await UpdateInstaller.install(path);
  } on UpdateInstallPermissionException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Нужно разрешение'),
          content: Text(
            '${e.message}\n\nОткройте настройки и разрешите установку приложений из этого источника, затем вернитесь и нажмите «Установить» снова.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                await UpdateInstaller.openInstallSettings();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Открыть настройки'),
            ),
          ],
        ),
      );
    }
    return;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ошибка обновления'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
    return;
  }
  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

String _formatBytes(int bytes) {
  const units = ['Б', 'КБ', 'МБ', 'ГБ'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 10 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
