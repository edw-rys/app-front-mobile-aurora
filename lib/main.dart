import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/di/injection.dart';
import 'app/router/router.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/background_service_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize professional background tracking
  try {
    await BackgroundTrackingUtils.initializeService();
  } catch (e) {
    debugPrint('Error initializing background service: $e');
  }

  // Validate environment configuration
  AppConfig.validate();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // Setup dependency injection
  await setupDependencies();

  runApp(const ProviderScope(child: MeterReadingsApp()));
}

class MeterReadingsApp extends ConsumerWidget {
  const MeterReadingsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Aurora',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
