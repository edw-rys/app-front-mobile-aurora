import '../models/user_model.dart';
import '../services/local/preferences_service.dart';
import '../services/remote/api_service.dart';

/// Repository for authentication operations
class AuthRepository {
  final ApiService _apiService;
  final PreferencesService _prefsService;

  AuthRepository({
    required ApiService apiService,
    required PreferencesService prefsService,
  })  : _apiService = apiService,
        _prefsService = prefsService;

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return _prefsService.hasTokens();
  }

  /// Login with email and password
  Future<UserModel> login(String email, String password) async {
    final response = await _apiService.login(email, password);
    final payload = response['payload'] as Map<String, dynamic>;

    // Save tokens
    await _prefsService.saveTokens(
      accessToken: payload['access_token'] as String,
      refreshToken: payload['refresh_token'] as String,
    );

    // Get user profile
    final user = UserModel.fromJson(payload['user'] as Map<String, dynamic>);
    await _prefsService.saveUser(user);
    return user;
  }

  /// Logout - clears tokens and user data but KEEPS local readings
  Future<void> logout() async {
    // Fire and forget logout call to the server
    _apiService.logout().catchError((_) {
      // Ignore errors, we are clearing local data anyway
    });
    
    await _prefsService.clearAuthData();
    // DO NOT clear SQLite readings here - they persist
  }

  /// Get current user from local storage
  Future<UserModel?> getCachedUser() async {
    return _prefsService.getUser();
  }

  /// Refresh profile from API
  Future<UserModel> refreshProfile() async {
    final user = await _apiService.getProfile();
    await _prefsService.saveUser(user);
    return user;
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    return _prefsService.getAccessToken();
  }
}
