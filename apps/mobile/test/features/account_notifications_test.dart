import 'dart:convert';

import 'package:bitesbox/core/network/api_client.dart';
import 'package:bitesbox/features/customer/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = '00000000-0000-4000-8000-000000000001';

void main() {
  late _NotificationServer server;
  late _AppSession app;

  setUp(() {
    server = _NotificationServer();
    app = _AppSession(server);
  });
  tearDown(() => app.close());

  test('signed-out customers do not issue a notification query', () async {
    final repository = await app.open(signedIn: false);

    expect(await repository.notifications(), isEmpty);
    expect(server.requests, isEmpty);
  });

  test(
    'opening a notification stays read after closing and restoring the app',
    () async {
      final repository = await app.open();
      final initial = await repository.notifications(limit: 20);
      expect(initial.map((item) => item.id), ['in-app-new', 'in-app-old']);

      expect(await repository.markNotificationsRead(ids: ['in-app-new']), 1);
      await app.close();

      // A new Supabase client and repository have no screen-local optimistic state.
      final restored = await app.open();
      final reloaded = await restored.notifications();
      expect(reloaded.first.isUnread, isFalse);
      expect(reloaded.last.isUnread, isTrue);
      expect(reloaded.where((item) => item.isUnread).length, 1);
      expect(server.row('push')['read_at'], isNull);
      expect(server.row('sms')['read_at'], isNull);

      for (final request in server.requests.where((r) => r.method == 'GET')) {
        expect(request.url.queryParameters['user_id'], 'eq.$_userId');
        expect(request.url.queryParameters['channel'], 'eq.IN_APP');
        expect(
          request.url.queryParameters['order'],
          'created_at.desc.nullslast',
        );
      }
      expect(server.requests.first.url.queryParameters['limit'], '20');
    },
  );

  test(
    'mark all stays read after restart and does not change push or SMS delivery',
    () async {
      final repository = await app.open();
      expect(await repository.markNotificationsRead(), 2);
      expect(await repository.markNotificationsRead(), 0);
      await app.close();

      final restored = await app.open();
      final reloaded = await restored.notifications();
      expect(reloaded, hasLength(2));
      expect(reloaded.where((item) => item.isUnread), isEmpty);
      for (final id in ['push', 'sms']) {
        expect(server.row(id)['read_at'], isNull);
        expect(server.row(id)['status'], 'QUEUED');
      }
    },
  );
}

class _AppSession {
  _AppSession(this.server);

  final _NotificationServer server;
  SupabaseClient? _client;
  MockClient? _transport;

  Future<AccountRepository> open({bool signedIn = true}) async {
    await close();
    _transport = MockClient(server.handle);
    final client = SupabaseClient(
      'https://example.test',
      'sb_publishable_test',
      httpClient: _transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    _client = client;
    if (signedIn) {
      String segment(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${segment({'alg': 'HS256'})}.${segment({'sub': _userId, 'exp': 4102444800})}.test';
      await client.auth.setInitialSession(
        jsonEncode({
          'access_token': token,
          'token_type': 'bearer',
          'refresh_token': 'test-refresh',
          'user': {'id': _userId, 'aud': 'authenticated'},
        }),
      );
    }
    return AccountRepository(ApiClient(client));
  }

  Future<void> close() async {
    await _client?.dispose();
    _client = null;
    _transport?.close();
    _transport = null;
  }
}

class _NotificationServer {
  final requests = <http.Request>[];
  final _rows = [
    _notification('in-app-new', 'IN_APP', '2026-10-22T10:00:00Z'),
    _notification('in-app-old', 'IN_APP', '2026-10-21T10:00:00Z'),
    _notification('push', 'PUSH', '2026-10-22T10:00:00Z'),
    _notification('sms', 'SMS', '2026-10-22T10:00:00Z'),
  ];

  Map<String, dynamic> row(String id) =>
      _rows.singleWhere((row) => row['id'] == id);

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/notifications') {
      final parameters = request.url.queryParameters;
      // Like production RLS, the server restricts ownership. The channel filter
      // must come from the app or delivery queue entries will enter the inbox.
      var visible = _rows.where((row) => row['user_id'] == _userId);
      for (final column in ['user_id', 'channel']) {
        final filter = parameters[column];
        if (filter != null) {
          visible = visible.where((row) => 'eq.${row[column]}' == filter);
        }
      }
      final ordered = visible.toList();
      if (parameters['order'] == 'created_at.desc.nullslast') {
        ordered.sort(
          (a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String),
        );
      }
      final limit = int.tryParse(parameters['limit'] ?? '') ?? ordered.length;
      return _response(request, ordered.take(limit).toList());
    }
    if (request.method == 'POST' &&
        request.url.path == '/rest/v1/rpc/mark_notifications_read') {
      final params = jsonDecode(request.body) as Map<String, dynamic>;
      final ids = params['p_ids'] as List<dynamic>?;
      var count = 0;
      for (final row in _rows) {
        if (row['user_id'] == _userId &&
            row['channel'] == 'IN_APP' &&
            row['read_at'] == null &&
            (ids == null || ids.contains(row['id']))) {
          row['read_at'] = '2026-10-22T11:00:00Z';
          row['status'] = 'READ';
          count++;
        }
      }
      return _response(request, count);
    }
    throw StateError('Unexpected request: ${request.method} ${request.url}');
  }

  static Map<String, dynamic> _notification(
    String id,
    String channel,
    String createdAt,
  ) => {
    'id': id,
    'user_id': _userId,
    'channel': channel,
    'status': 'QUEUED',
    'event': 'ORDER_CANCELLED',
    'title': 'Order update',
    'body': 'Your order was cancelled.',
    'read_at': null,
    'created_at': createdAt,
  };

  http.Response _response(http.Request request, Object value) => http.Response(
    jsonEncode(value),
    200,
    request: request,
    headers: {'content-type': 'application/json'},
  );
}
