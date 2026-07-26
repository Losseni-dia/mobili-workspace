import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/core/services/firebase_service.dart';
import 'package:mobilipro/core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  await initializeDateFormatting('fr_FR', null);

  // Firebase : lancé en arrière-plan, SANS bloquer l'affichage du premier
  // écran. Les notifications push s'activeront quelques instants après
  // le démarrage, sans faire attendre l'utilisateur.
  // ignore: unawaited_futures
  FirebaseService.initialize();

  runApp(const ProviderScope(child: MobiliProApp()));
}

class MobiliProApp extends ConsumerWidget {
  const MobiliProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'MobiliPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
