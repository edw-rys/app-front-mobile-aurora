import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/meter_list_screen.dart';
import '../../presentation/screens/meter_detail_screen.dart';
import '../../presentation/screens/map_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/user_guide_screen.dart';
import '../../presentation/screens/main_shell.dart';
import '../../presentation/screens/sync_result_screen.dart';
import '../../data/repositories/meter_repository.dart';

/// Provider for GoRouter to make it reactive to auth changes
final routerProvider = Provider<GoRouter>((ref) {
  // Use a Listenable that notifies ONLY when authentication status changes
  final authStateListenable = ValueNotifier<bool>(ref.read(authProvider).isAuthenticated);
  
  // Update listenable when authState changes
  ref.listen(authProvider, (prev, next) {
    if (prev?.isAuthenticated != next.isAuthenticated) {
      authStateListenable.value = next.isAuthenticated;
    }
  });

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    refreshListenable: authStateListenable,
    redirect: (context, state) {
      // Always get the latest state without triggering a router rebuild
      final authState = ref.read(authProvider);
      
      final isLoggedIn = authState.isAuthenticated;
      final isOnLogin = state.matchedLocation == '/login';

      if (authState.isInitializing) return null;

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/sync-result',
        builder: (context, state) {
          final result = state.extra as SyncResult?;
          // Fallback if accessed directly
          if (result == null) return const HomeScreen(); 
          return SyncResultScreen(result: result);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/meters',
            builder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return MeterListScreen(initialFilter: filter);
            },
          ),
          GoRoute(
            path: '/meters/:nAbonado',
            builder: (context, state) {
              final nAbonado = state.pathParameters['nAbonado']!;
              return MeterDetailScreen(nAbonado: nAbonado);
            },
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/user-guide',
            builder: (context, state) => const UserGuideScreen(),
          ),
        ],
      ),
    ],
  );
});
