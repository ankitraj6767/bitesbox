import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Firebase Cloud Messaging, wrapped so the rest of the app never has to care
/// whether push is configured on this build.
///
/// Two deliberate decisions:
///
///  * Configuration comes from `--dart-define`, not a committed
///    `google-services.json`. A fork of this repository carries no project
///    identity, and dev/staging/prod differ by build flag rather than by file.
///  * Absence is not failure. Order updates already arrive over Supabase
///    Realtime and land in the in-app inbox, so a build without FCM keys is
///    fully functional — it simply cannot wake the app when it is closed.
class PushService {
  PushService();

  bool _initialised = false;
  bool _available = false;
  FirebaseMessaging? _messaging;

  bool get isAvailable => _available;

  /// Safe to call repeatedly; the work happens once.
  Future<bool> initialise() async {
    if (_initialised) return _available;
    _initialised = true;

    if (!Env.pushEnabled) {
      debugPrint('Push disabled: no Firebase client configuration supplied.');
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options());
      }
      _messaging = FirebaseMessaging.instance;
      _available = true;
    } on Object catch (error) {
      // A misconfigured push setup must never stop a customer from ordering.
      debugPrint('Push unavailable: $error');
      _available = false;
    }

    return _available;
  }

  static FirebaseOptions _options() => FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseSenderId,
        projectId: Env.firebaseProjectId,
        storageBucket:
            Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
      );

  /// Asks for permission and reports whether we may actually notify.
  ///
  /// Android below 13 and iOS both grant silently or via the system prompt; a
  /// declined prompt is a normal outcome, not an error.
  Future<bool> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) return false;

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } on Object catch (error) {
      debugPrint('Push permission request failed: $error');
      return false;
    }
  }

  /// The device token, or null when push is unavailable or was declined.
  Future<String?> token() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    try {
      // APNs has to hand us a token before FCM can mint one on iOS.
      if (Platform.isIOS || Platform.isMacOS) {
        final apns = await messaging.getAPNSToken();
        if (apns == null) return null;
      }

      return await messaging.getToken();
    } on Object catch (error) {
      debugPrint('Could not read the push token: $error');
      return null;
    }
  }

  /// Fires when Firebase rotates the token, which invalidates the stored one.
  Stream<String> get onTokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  /// Messages that land while the app is in the foreground. The OS does not show
  /// these on Android, so the app surfaces them itself.
  Stream<RemoteMessage> get onMessage =>
      _available ? FirebaseMessaging.onMessage : const Stream<RemoteMessage>.empty();

  /// The user tapped a notification while the app was backgrounded.
  Stream<RemoteMessage> get onMessageOpenedApp => _available
      ? FirebaseMessaging.onMessageOpenedApp
      : const Stream<RemoteMessage>.empty();

  /// The notification that cold-started the app, if any.
  Future<RemoteMessage?> initialMessage() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    try {
      return await messaging.getInitialMessage();
    } on Object catch (error) {
      debugPrint('Could not read the launch notification: $error');
      return null;
    }
  }

  /// Drops the token on this device. Used at sign-out so a shared handset stops
  /// receiving the previous user's order updates.
  Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
    } on Object catch (error) {
      debugPrint('Could not delete the push token: $error');
    }
  }
}

/// What a Bites Box notification asks the app to do.
///
/// The payload mirrors `app.enqueue_notification`, which always includes the
/// event name and, where relevant, the order it concerns.
@immutable
class PushPayload {
  const PushPayload({
    required this.title,
    required this.body,
    this.event,
    this.orderId,
    this.ticketId,
  });

  final String title;
  final String body;
  final String? event;
  final String? orderId;
  final String? ticketId;

  bool get hasContent => title.isNotEmpty || body.isNotEmpty;

  /// Where tapping this notification should land the user.
  String? get deepLink {
    if (orderId != null && orderId!.isNotEmpty) return '/order/$orderId';
    if (ticketId != null && ticketId!.isNotEmpty) return '/support/$ticketId';
    return null;
  }

  factory PushPayload.fromMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return PushPayload(
      title: notification?.title ?? _string(data['title']),
      body: notification?.body ?? _string(data['body']),
      event: _nullable(data['event']),
      orderId: _nullable(data['order_id']),
      ticketId: _nullable(data['ticket_id']),
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static String? _nullable(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return value;
  }
}
