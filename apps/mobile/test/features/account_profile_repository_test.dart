import 'dart:convert';

import 'package:bitesbox/core/network/api_client.dart';
import 'package:bitesbox/features/customer/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('profile RPC omits untouched notification consent fields', () async {
    late http.Request request;
    final transport = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({'id': 'u1'}),
        200,
        request: incoming,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient('https://example.test', 'sb_publishable_test',
        httpClient: transport, authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async { await client.dispose(); transport.close(); });

    await AccountRepository(ApiClient(client)).updateProfile(
      fullName: ' Ankit Raj ',
      email: ' ankit@example.test ',
    );

    expect(request.url.path, '/rest/v1/rpc/update_my_profile');
    expect(jsonDecode(request.body), {
      'p_full_name': 'Ankit Raj',
      'p_email': 'ankit@example.test',
    });
  });

  test('explicit channel changes are the only consent values sent', () async {
    late http.Request request;
    final transport = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        jsonEncode({'id': 'u1'}),
        200,
        request: incoming,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient('https://example.test', 'sb_publishable_test',
        httpClient: transport, authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async { await client.dispose(); transport.close(); });

    await AccountRepository(ApiClient(client)).updateProfile(
      whatsappEnabled: false,
      marketingOptIn: true,
    );

    expect(jsonDecode(request.body), {
      'p_marketing_opt_in': true,
      'p_whatsapp_enabled': false,
    });
  });
}
