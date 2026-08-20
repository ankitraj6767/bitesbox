import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';
import '../network/api_client.dart';
import 'session.dart';

/// Phone-first authentication.
///
/// The OTP provider is configured server-side (Supabase Auth SMS settings), so
/// swapping MSG91 for Twilio is an operations change, not an app release. The app
/// only ever asks "send a code to this number" and "here is the code".
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Stream<AuthState> get authStateChanges => _api.auth.onAuthStateChange;

  bool get isSignedIn => _api.isSignedIn;
  String? get currentUserId => _api.currentUserId;

  /// Sends a login code. Supabase enforces resend throttling; the UI shows a
  /// countdown driven by the `otp.resend_seconds` setting.
  Future<void> sendOtp(String phone) async {
    try {
      await _api.auth.signInWithOtp(phone: _normalise(phone));
    } catch (error, stackTrace) {
      throw AppError.from(error, stackTrace);
    }
  }

  /// Verifies the code and establishes a session.
  Future<AppSession> verifyOtp({required String phone, required String token}) async {
    try {
      await _api.auth.verifyOTP(
        phone: _normalise(phone),
        token: token.trim(),
        type: OtpType.sms,
      );
    } catch (error, stackTrace) {
      final mapped = AppError.from(error, stackTrace);

      // Supabase reports a wrong or stale code as a 4xx auth error; give the
      // customer copy they can act on instead of the raw provider message.
      if (mapped.code != ErrorCodes.networkError && mapped.code != ErrorCodes.timeout) {
        throw AppError(
          code: 'OTP_INVALID',
          message: 'That code is incorrect or has expired. Please try again.',
          cause: mapped.cause,
        );
      }
      throw mapped;
    }

    return loadSession();
  }

  /// Email + password, used by staff on shared kitchen tablets where a phone is
  /// impractical.
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _api.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } catch (error, stackTrace) {
      final mapped = AppError.from(error, stackTrace);
      if (mapped.code == 'INVALID_CREDENTIALS') {
        throw const AppError(
          code: 'INVALID_CREDENTIALS',
          message: 'Those details do not match an account.',
        );
      }
      throw mapped;
    }

    return loadSession();
  }

  /// Loads identity, live permissions and branch scope.
  ///
  /// Permissions come from the database rather than the JWT, so revoking access
  /// takes effect immediately instead of at the next token refresh.
  Future<AppSession> loadSession() async {
    if (!_api.isSignedIn) return const AppSession.guest();

    final result = await _api.rpc<dynamic>('my_session');
    if (result is! Map) return const AppSession.guest();

    return AppSession.fromJson(Map<String, dynamic>.from(result));
  }

  Future<void> signOut({String? deviceToken}) async {
    // Detach this device first so a shared handset stops receiving the previous
    // user's order notifications.
    if (deviceToken != null && deviceToken.isNotEmpty) {
      try {
        await _api.rpc<dynamic>('unregister_device_token', params: {'p_token': deviceToken});
      } catch (_) {
        // Never block sign-out on a failed cleanup.
      }
    }

    await _api.auth.signOut();
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? email,
    String? preferredLanguage,
    bool? marketingOptIn,
  }) async {
    final result = await _api.rpc<dynamic>('update_my_profile', params: {
      if (fullName != null) 'p_full_name': fullName,
      if (email != null && email.isNotEmpty) 'p_email': email,
      if (preferredLanguage != null) 'p_preferred_language': preferredLanguage,
      if (marketingOptIn != null) 'p_marketing_opt_in': marketingOptIn,
    });

    return UserProfile.fromJson(Map<String, dynamic>.from(result as Map));
  }

  /// Registers this device for push. Multiple devices per user are supported;
  /// the token is the primary key so re-registering is idempotent.
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceModel,
    String? osVersion,
    String? appVersion,
    String? locale,
  }) async {
    await _api.rpc<dynamic>('register_device_token', params: {
      'p_token': token,
      'p_platform': platform,
      'p_device_model': deviceModel,
      'p_os_version': osVersion,
      'p_app_version': appVersion,
      'p_locale': locale,
    });
  }

  /// Indian mobile numbers to E.164, matching `app.normalize_phone` in Postgres.
  static String _normalise(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      digits = '91$digits';
    }

    return '+$digits';
  }

  /// Exposed for the sign-in screen's validation.
  static bool isValidIndianMobile(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return local.length == 10 && RegExp(r'^[6-9]').hasMatch(local);
  }
}
