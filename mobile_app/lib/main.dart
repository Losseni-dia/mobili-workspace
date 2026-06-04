import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';          // ← ajoute
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/network/api_client.dart'; 
import 'core/router/go_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Polices Google Fonts (bundlées, pas de fetch réseau) ──
  GoogleFonts.config.allowRuntimeFetching = true;         // ← ajoute

  // ── Hive (cache offline) ──────────────────────────────────
  final appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);

  // ── Initialisation du Client API ──────────────────────────
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
      theme: AppTheme.light,      
      darkTheme: AppTheme.dark,     
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}