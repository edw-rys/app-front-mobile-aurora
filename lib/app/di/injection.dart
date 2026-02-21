import 'package:get_it/get_it.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../../data/services/local/database_service.dart';
import '../../data/services/local/preferences_service.dart';
import '../../data/services/remote/api_service.dart';

/// Service locator setup
final getIt = GetIt.instance;

/// Register all dependencies
Future<void> setupDependencies() async {
  // ─── Services (Singletons) ──────────────────────────────
  getIt.registerLazySingleton<PreferencesService>(
    () => PreferencesService(),
  );

  getIt.registerLazySingleton<DatabaseService>(
    () => DatabaseService(),
  );

  getIt.registerLazySingleton<ApiService>(
    () => ApiService(prefsService: getIt<PreferencesService>()),
  );

  // ─── Repositories ─────────────────────────────────────────
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      apiService: getIt<ApiService>(),
      prefsService: getIt<PreferencesService>(),
    ),
  );

  getIt.registerLazySingleton<MeterRepository>(
    () => MeterRepository(
      apiService: getIt<ApiService>(),
      dbService: getIt<DatabaseService>(),
      prefsService: getIt<PreferencesService>(),
    ),
  );
}
