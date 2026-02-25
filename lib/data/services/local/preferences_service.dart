import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

/// SharedPreferences wrapper for auth tokens and app state
class PreferencesService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _currentPeriodIdKey = 'current_period_id';
  static const String _parentIdKey = 'parent_id';
  static const String _workStartedKey = 'work_started';
  static const String _notificationIntervalKey = 'notification_interval';
  static const String _autoSyncEnabledKey = 'auto_sync_enabled';
  static const String _gpsOnboardingShownKey = 'gps_onboarding_shown';
  static const String _cameraOnboardingShownKey = 'camera_onboarding_shown';
  static const String _cameraFlashModeKey = 'camera_flash_mode';
  static const String _enablePhotoKey = 'enable_photo';
  static const String _requirePhotoKey = 'require_photo';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Tokens ───────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await prefs;
    await p.setString(_accessTokenKey, accessToken);
    await p.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getAccessToken() async {
    final p = await prefs;
    return p.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final p = await prefs;
    return p.getString(_refreshTokenKey);
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ─── User Data ────────────────────────────────────────────

  Future<void> saveUser(UserModel user) async {
    final p = await prefs;
    await p.setString(_userDataKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final p = await prefs;
    final data = p.getString(_userDataKey);
    if (data == null) return null;
    return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }

  // ─── Period State ─────────────────────────────────────────

  Future<void> savePeriodId(String periodId) async {
    final p = await prefs;
    await p.setString(_currentPeriodIdKey, periodId);
  }

  Future<String?> getPeriodId() async {
    final p = await prefs;
    return p.getString(_currentPeriodIdKey);
  }

  Future<void> saveParentId(int parentId) async {
    final p = await prefs;
    await p.setInt(_parentIdKey, parentId);
  }

  Future<int?> getParentId() async {
    final p = await prefs;
    return p.getInt(_parentIdKey);
  }

  Future<void> setWorkStarted(bool started) async {
    final p = await prefs;
    await p.setBool(_workStartedKey, started);
  }

  Future<bool> isWorkStarted() async {
    final p = await prefs;
    return p.getBool(_workStartedKey) ?? false;
  }

  /// Save full period info from API aditionalParams
  Future<void> savePeriodInfo(Map<String, dynamic> periodInfo) async {
    final p = await prefs;
    await p.setString('period_info', jsonEncode(periodInfo));
    // Persist photo flags directly for quick access
    final enablePhoto = periodInfo['enable_photo'] as bool? ?? false;
    final requirePhoto = periodInfo['require_photo'] as bool? ?? false;
    await p.setBool(_enablePhotoKey, enablePhoto);
    await p.setBool(_requirePhotoKey, requirePhoto);
  }

  /// Get saved period info
  Future<Map<String, dynamic>?> getPeriodInfo() async {
    final p = await prefs;
    final data = p.getString('period_info');
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  /// Get enable_photo flag for current period
  Future<bool> getEnablePhoto() async {
    final p = await prefs;
    return p.getBool(_enablePhotoKey) ?? false;
  }

  /// Get require_photo flag for current period
  Future<bool> getRequirePhoto() async {
    final p = await prefs;
    return p.getBool(_requirePhotoKey) ?? false;
  }

  // ─── Settings ─────────────────────────────────────────────

  Future<void> setNotificationInterval(int minutes) async {
    final p = await prefs;
    await p.setInt(_notificationIntervalKey, minutes);
  }

  Future<int> getNotificationInterval() async {
    final p = await prefs;
    return p.getInt(_notificationIntervalKey) ?? 120;
  }

  Future<bool> getAutoSyncEnabled() async {
    final p = await prefs;
    return p.getBool(_autoSyncEnabledKey) ?? false;
  }

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_autoSyncEnabledKey, enabled);
  }

  Future<void> setGpsOnboardingShown(bool shown) async {
    final p = await prefs;
    await p.setBool(_gpsOnboardingShownKey, shown);
  }

  Future<bool> isGpsOnboardingShown() async {
    final p = await prefs;
    return p.getBool(_gpsOnboardingShownKey) ?? false;
  }

  Future<void> setCameraOnboardingShown(bool shown) async {
    final p = await prefs;
    await p.setBool(_cameraOnboardingShownKey, shown);
  }

  Future<bool> isCameraOnboardingShown() async {
    final p = await prefs;
    return p.getBool(_cameraOnboardingShownKey) ?? false;
  }

  Future<void> setCameraFlashMode(String mode) async {
    final p = await prefs;
    await p.setString(_cameraFlashModeKey, mode);
  }

  Future<String> getCameraFlashMode() async {
    final p = await prefs;
    return p.getString(_cameraFlashModeKey) ?? 'off'; // Default to off
  }

  // ─── Clear ────────────────────────────────────────────────

  /// Clear auth data only (tokens + user) - keeps readings!
  Future<void> clearAuthData() async {
    final p = await prefs;
    await p.remove(_accessTokenKey);
    await p.remove(_refreshTokenKey);
    await p.remove(_userDataKey);
    await p.remove(_gpsOnboardingShownKey);
  }

  /// Clear all preferences
  Future<void> clearAll() async {
    final p = await prefs;
    await p.clear();
  }
}
