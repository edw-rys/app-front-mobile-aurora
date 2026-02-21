import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/di/injection.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/remote/api_service.dart';
import '../../core/exceptions/dio_exception_handler.dart';

/// Auth state
class AuthState {
  final bool isInitializing;
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isInitializing = false,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isInitializing,
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isInitializing: isInitializing ?? this.isInitializing,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final ApiService _apiService;
  StreamSubscription? _authErrorSub;

  AuthNotifier({
    required AuthRepository authRepo,
    required ApiService apiService,
  })  : _authRepo = authRepo,
        _apiService = apiService,
        super(const AuthState(isInitializing: true)) {
    _authErrorSub = _apiService.authErrors.listen((_) {
      state = const AuthState();
    });
    checkAuth();
  }

  @override
  void dispose() {
    _authErrorSub?.cancel();
    super.dispose();
  }

  /// Check initial auth state
  Future<void> checkAuth() async {
    try {
      final isAuth = await _authRepo.isAuthenticated();
      if (isAuth) {
        final user = await _authRepo.getCachedUser();
        state = state.copyWith(
          isInitializing: false,
          isAuthenticated: true,
          user: user,
        );
      } else {
        state = state.copyWith(isInitializing: false);
      }
    } catch (_) {
      state = state.copyWith(isInitializing: false);
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authRepo.login(email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: DioExceptionHandler.mapToString(e),
      );
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authRepo.logout();
    state = const AuthState();
  }

  /// Refresh profile
  Future<void> refreshProfile() async {
    try {
      final user = await _authRepo.refreshProfile();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authRepo: getIt<AuthRepository>(),
    apiService: getIt<ApiService>(),
  );
});
