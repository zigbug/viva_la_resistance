import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'app_config.dart';

Future<void> installRuleSets(
  String workingPath,
  Iterable<ServiceId> services,
) async {
  final directory = Directory(p.join(workingPath, 'rule-sets'));
  await directory.create(recursive: true);

  for (final service in services) {
    final data = await rootBundle.load('assets/rule-sets/${service.assetFile}');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final file = File(p.join(directory.path, service.assetFile));
    if (await file.exists() && await file.length() == bytes.length) {
      continue;
    }
    await file.writeAsBytes(bytes, flush: true);
  }
}
