import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EnginePaths {
  const EnginePaths({
    required this.base,
    required this.working,
    required this.temp,
  });

  final String base;
  final String working;
  final String temp;

  static Future<EnginePaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final temp = await getTemporaryDirectory();
    final base = p.join(support.path, 'engine');
    final working = p.join(base, 'working');
    await Directory(working).create(recursive: true);
    return EnginePaths(base: base, working: working, temp: temp.path);
  }
}
