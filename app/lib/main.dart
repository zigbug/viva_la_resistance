import 'package:flutter/material.dart';
import 'package:flutter_singbox_client/flutter_singbox_client.dart';

import 'app_config.dart';
import 'engine_paths.dart';
import 'home_screen.dart';
import 'vpn_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final paths = await EnginePaths.resolve();
    final client = SingboxClient();
    await client.initialize(
      EngineOptions(
        basePath: paths.base,
        workingPath: paths.working,
        tempPath: paths.temp,
      ),
    );
    final config = await AppConfig.load();
    runApp(VivaApp(client: client, paths: paths, config: config));
  } catch (error) {
    runApp(StartupErrorApp(message: _describeError(error)));
  }
}

String _describeError(Object error) {
  if (error is ConfigException) {
    return error.message;
  }
  final text = error.toString();
  const prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}

class VivaApp extends StatelessWidget {
  const VivaApp({
    super.key,
    required this.client,
    required this.paths,
    required this.config,
  });

  final SingboxClient client;
  final EnginePaths paths;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4CAF50),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: config.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF101412),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: HomeScreen(
        controller: VpnController(client: client, paths: paths, config: config),
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFEF5350),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Viva la Resistance')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось запустить',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        message,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
