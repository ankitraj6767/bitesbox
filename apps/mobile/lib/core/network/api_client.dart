import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_error.dart';

/// Thin wrapper over the Supabase client.
///
/// Responsibilities kept deliberately narrow:
///   · one place that converts transport/database errors into [AppError]
///   · timeouts, so a stalled request on a weak mobile network fails cleanly
///   · retry with backoff for genuinely transient failures only
///   · request de-duplication, so a double tap issues one call
///
/// Business logic never lives here. It lives in Postgres and Edge Functions.
class ApiClient {
  ApiClient(this._client);

  final SupabaseClient _client;

  /// Ordering happens on patchy connections; long enough to survive a hiccup,
  /// short enough that the UI does not appear frozen.
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _writeTimeout = Duration(seconds: 30);

  final Map<String, Future<dynamic>> _inFlight = {};

  SupabaseClient get raw => _client;
  GoTrueClient get auth => _client.auth;
  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  bool get isSignedIn => _client.auth.currentUser != null;

  /// Calls a Postgres function.
  ///
  /// [dedupeKey] collapses concurrent identical calls — a customer mashing
  /// "Add to cart" produces one request, not five.
  Future<T> rpc<T>(
    String function, {
    Map<String, dynamic>? params,
    Duration? timeout,
    int retries = 1,
    String? dedupeKey,
  }) async {
    if (dedupeKey != null) {
      final existing = _inFlight[dedupeKey];
      if (existing != null) return await existing as T;
    }

    final future = _run<T>(
      () async {
        final result = await _client
            .rpc(function, params: params)
            .timeout(timeout ?? _defaultTimeout);
        return result as T;
      },
      retries: retries,
    );

    if (dedupeKey != null) {
      _inFlight[dedupeKey] = future;
      try {
        return await future;
      } finally {
        _inFlight.remove(dedupeKey);
      }
    }

    return future;
  }

  /// Calls an Edge Function. Never retried by default: these endpoints create
  /// orders and payments, and an idempotency key — not a retry — is the correct
  /// tool for making them safe.
  Future<Map<String, dynamic>> invoke(
    String function, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    return _run<Map<String, dynamic>>(
      () async {
        final response = await _client.functions
            .invoke(function, body: body ?? const {})
            .timeout(timeout ?? _writeTimeout);

        final data = response.data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return <String, dynamic>{'data': data};
      },
      retries: 0,
    );
  }

  /// Table read. RLS decides which rows come back.
  PostgrestQueryBuilder from(String table) => _client.from(table);

  Future<List<Map<String, dynamic>>> select(
    String table, {
    required String columns,
    Duration? timeout,
    void Function(PostgrestFilterBuilder<PostgrestList> query)? filter,
  }) async {
    return _run<List<Map<String, dynamic>>>(
      () async {
        var query = _client.from(table).select(columns);
        filter?.call(query);
        final rows = await query.timeout(timeout ?? _defaultTimeout);
        return List<Map<String, dynamic>>.from(rows);
      },
      retries: 1,
    );
  }

  /// Runs [action], mapping failures to [AppError] and retrying only what is
  /// safe to retry.
  Future<T> _run<T>(Future<T> Function() action, {required int retries}) async {
    var attempt = 0;

    while (true) {
      try {
        return await action();
      } catch (error, stackTrace) {
        final appError = AppError.from(error, stackTrace);

        final canRetry = attempt < retries && appError.isRetryable;
        if (!canRetry) throw appError;

        attempt += 1;
        // Short exponential backoff: 400ms, 800ms.
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }
}
