import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/router/go_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive (cache offline) ──────────────────────────────────
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  // Les boîtes Hive sont ouvertes dans leurs repositories respectifs
  // via ref.watch() au premier accès — pas d'ouverture globale ici.

  // ── Initialisation du Client API (Nouveau) ──────────────────
  await ApiClient.init();

  runApp(
    const ProviderScope(
      child: MobiliApp(),
    ),
  );
}

class MobiliApp extends ConsumerWidget {
  const MobiliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Mobili',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
