import 'dart:convert';

import 'package:bitesbox/core/network/api_client.dart';
import 'package:bitesbox/features/customer/data/address_repository.dart';
import 'package:bitesbox/features/customer/data/content_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'select sends the returned filter, ordering and limit to Supabase',
    () async {
      late Uri requestedUrl;
      final api = _api((request) async {
        requestedUrl = request.url;
        return _jsonResponse(request, [
          {'id': 'notification-1'},
        ]);
      });

      final rows = await api.select(
        'notifications',
        columns: 'id',
        filter: (query) => query
            .eq('user_id', 'customer-1')
            .eq('channel', 'IN_APP')
            .order('created_at', ascending: false)
            .limit(12),
      );

      expect(requestedUrl.path, '/rest/v1/notifications');
      expect(requestedUrl.queryParameters, {
        'select': 'id',
        'user_id': 'eq.customer-1',
        'channel': 'eq.IN_APP',
        'order': 'created_at.desc.nullslast',
        'limit': '12',
      });
      expect(rows.single['id'], 'notification-1');
    },
  );

  test(
    'saved addresses still load without a filter callback and sort default first',
    () async {
      final api = _api((request) async {
        expect(request.url.path, '/rest/v1/addresses');
        expect(request.url.queryParameters.keys, ['select']);
        return _jsonResponse(request, [
          {'id': 'work', 'label': 'WORK', 'is_default': false},
          {'id': 'home', 'label': 'HOME', 'is_default': true},
        ]);
      });

      final addresses = await AddressRepository(api).list();

      expect(addresses.map((address) => address.id), ['home', 'work']);
    },
  );

  test('policy documents retain published and locale filters', () async {
    final api = _api((request) async {
      expect(request.url.path, '/rest/v1/cms_documents');
      expect(request.url.queryParameters['is_published'], 'eq.true');
      expect(request.url.queryParameters['locale'], 'eq.hi');
      expect(request.url.queryParameters['order'], 'kind.desc.nullslast');
      return _jsonResponse(request, [
        {'id': 'terms-hi', 'kind': 'TERMS', 'locale': 'hi'},
      ]);
    });

    final documents = await ContentRepository(api).documents(locale: 'hi');

    expect(documents.single.id, 'terms-hi');
    expect(documents.single.locale, 'hi');
  });

  test('FAQs retain both ordering fields and the selected locale', () async {
    final api = _api((request) async {
      expect(request.url.path, '/rest/v1/cms_faqs');
      expect(request.url.queryParameters['is_published'], 'eq.true');
      expect(request.url.queryParameters['locale'], 'eq.en');
      expect(
        request.url.queryParameters['order'],
        'category.desc.nullslast,display_order.desc.nullslast',
      );
      return _jsonResponse(request, [
        {'id': 'faq-en', 'locale': 'en'},
      ]);
    });

    final faqs = await ContentRepository(api).faqs();

    expect(faqs.single.id, 'faq-en');
  });
}

ApiClient _api(Future<http.Response> Function(http.Request) handler) {
  final transport = MockClient(handler);
  final client = SupabaseClient(
    'https://example.test',
    'sb_publishable_test',
    httpClient: transport,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(() async {
    await client.dispose();
    transport.close();
  });
  return ApiClient(client);
}

http.Response _jsonResponse(http.Request request, Object value) =>
    http.Response(
      jsonEncode(value),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
