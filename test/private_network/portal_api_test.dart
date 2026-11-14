import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/private_network/portal_api.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Map<String, dynamic> value, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  test('recharge accepts only official HTTPS bill URLs', () {
    expect(RechargeOrder.fromJson({'payment_url': 'https://toyyibpay.com/abc123'}).paymentUrl?.host, 'toyyibpay.com');
    for (final value in [
      'http://toyyibpay.com/abc',
      'https://evil.example/abc',
      'https://toyyibpay.com.evil.example/abc',
      'https://x@toyyibpay.com/abc',
      'https://toyyibpay.com/abc?token=x',
      'https://toyyibpay.com:444/abc',
    ]) {
      expect(() => RechargeOrder.fromJson({'payment_url': value}), throwsA(isA<PortalFailure>()));
    }
  });
  test('email verification and order sync use expected authenticated routes', () async {
    final requests = <RequestOptions>[];
    final api = PortalApi(
      'https://vpn.example.com',
      adapter: FakeAdapter((request) {
        requests.add(request);
        return jsonResponse({'status': 'pending'});
      }),
    );
    await api.sendRegistrationCode('test@example.com');
    await api.register('test@example.com', 'Password123!', 'Password123!', code: '123456');
    await api.syncOrder('session', 'GBM12345678901234567890');
    expect(requests[0].path, '/api/auth/send-code');
    expect(requests[0].headers.containsKey('Authorization'), false);
    expect((requests[1].data as Map)['code'], '123456');
    expect(requests[2].path, '/api/order/GBM12345678901234567890/sync-toyyibpay');
    expect(requests[2].headers['Authorization'], 'Bearer session');
    api.close();
  });
  final origin = Uri.parse('https://vpn.example.com');
  test('rejects cleartext, credentials, path prefixes and URL metadata', () {
    for (final url in [
      'http://vpn.example.com',
      'https://user:pass@vpn.example.com',
      'https://vpn.example.com/api',
      'https://vpn.example.com?token=secret',
      'https://vpn.example.com#secret',
      '',
    ]) {
      expect(() => validatePortalOrigin(url), throwsA(isA<PortalFailure>()), reason: url);
    }
    expect(validatePortalOrigin(' https://vpn.example.com/ ').origin, origin.origin);
  });
  test('accepts only the configured HTTPS origin and exact subscription route', () {
    expect(validateSubscription(origin, 'https://vpn.example.com/sub/fixture_token'), isA<Uri>());
    for (final url in [
      'http://vpn.example.com/sub/fixture',
      'https://evil.example/sub/fixture',
      'https://vpn.example.com:444/sub/fixture',
      'https://vpn.example.com/sub/fixture?token=x',
      'https://vpn.example.com/sub/fixture#x',
      'https://secret@vpn.example.com/sub/fixture',
      'https://vpn.example.com/api/me',
      'https://vpn.example.com/sub/fixture/clash',
      '/sub/fixture',
    ]) {
      expect(() => validateSubscription(origin, url), throwsA(isA<PortalFailure>()), reason: url);
    }
  });
  test('login, me and logout match the existing portal contract', () async {
    final calls = <String>[];
    final api = PortalApi(
      origin.origin,
      adapter: FakeAdapter((request) {
        calls.add(request.path);
        expect(request.followRedirects, false);
        switch (request.path) {
          case '/api/login':
            expect(request.method, 'POST');
            expect((request.data as Map)['email'], 'test@example.com');
            expect(request.headers.containsKey('Authorization'), false);
            return jsonResponse({'session_token': 'fixture-session'});
          case '/api/me':
            expect(request.headers['Authorization'], 'Bearer fixture-session');
            return jsonResponse({
              'email': 'test@example.com',
              'subscription': {'subscription_url': '${origin.origin}/sub/fixture_token'},
              'prototype_notice': '尚未配置到真实 Xray',
            });
          case '/api/logout':
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], 'Bearer fixture-session');
            return jsonResponse({'message': 'Logged out successfully'});
          default:
            throw StateError('Unexpected route');
        }
      }),
    );
    addTearDown(api.close);
    final token = await api.login(' test@example.com ', 'fixture-password');
    final account = await api.me(token);
    expect(account.email, 'test@example.com');
    expect(account.notice, contains('Xray'));
    expect(account.toString(), isNot(contains('fixture_token')));
    await api.logout(token);
    expect(calls, ['/api/login', '/api/me', '/api/logout']);
  });
  test('registration includes password confirmation', () async {
    final api = PortalApi(
      origin.origin,
      adapter: FakeAdapter((request) {
        expect(request.path, '/api/register');
        expect(request.method, 'POST');
        expect(request.data, {
          'email': 'test@example.com',
          'password': 'fixture-password',
          'confirm_password': 'fixture-password',
        });
        return jsonResponse({'message': 'registered'}, 201);
      }),
    );
    addTearDown(api.close);
    await api.register('test@example.com', 'fixture-password', 'fixture-password');
  });
  test('unauthorized profile requests trigger reauthentication without leaking data', () async {
    final api = PortalApi(origin.origin, adapter: FakeAdapter((_) => jsonResponse({'detail': 'private-value'}, 401)));
    addTearDown(api.close);
    await expectLater(
      api.me('fixture-session'),
      throwsA(
        isA<PortalFailure>()
            .having((failure) => failure.unauthorized, 'unauthorized', true)
            .having((failure) => failure.toString().contains('private-value'), 'no private response', false),
      ),
    );
  });
  test('redirects and malformed JSON cannot become authenticated profiles', () async {
    final redirect = PortalApi(origin.origin, adapter: FakeAdapter((_) => jsonResponse({}, 302)));
    final malformed = PortalApi(origin.origin, adapter: FakeAdapter((_) => jsonResponse({'session_token': 123})));
    addTearDown(redirect.close);
    addTearDown(malformed.close);
    await expectLater(redirect.me('fixture-session'), throwsA(isA<PortalFailure>()));
    await expectLater(malformed.login('test@example.com', 'fixture-password'), throwsA(isA<PortalFailure>()));
  });
  test('rate limiting and invited registration return actionable messages', () async {
    for (final status in [429, 400, 403]) {
      final api = PortalApi(
        origin.origin,
        adapter: FakeAdapter((_) => jsonResponse({'detail': 'private-detail'}, status)),
      );
      addTearDown(api.close);
      await expectLater(
        api.register('test@example.com', 'fixture-password', 'fixture-password'),
        throwsA(
          isA<PortalFailure>().having(
            (failure) => failure.toString(),
            'message',
            contains(status == 429 ? '频繁' : '获邀'),
          ),
        ),
      );
    }
  });
  test('account node names are available before connecting without retaining node URIs', () {
    final data = <String, dynamic>{
      'email': 'test@example.com',
      'subscription': {'subscription_url': '${origin.origin}/sub/fixture_token'},
      'nodes': [
        {'name': ' Malaysia ', 'longitude': 101.69, 'latitude': 3.14, 'uri': 'private-fixture-link'},
      ],
    };
    final account = PortalAccount.fromJson(data, origin);
    expect(account.nodeNames, ['Malaysia']);
    expect(account.nodes.single.longitude, 101.69);
    expect(account.nodes.single.latitude, 3.14);
    expect(account.toString(), isNot(contains('private-fixture')));
    data['nodes'] = [
      {'name': ''},
    ];
    expect(() => PortalAccount.fromJson(data, origin), throwsA(isA<PortalFailure>()));
  });
  test('legacy Malaysia node payloads still locate on the globe', () {
    final account = PortalAccount.fromJson({
      'email': 'test@example.com',
      'subscription': {'subscription_url': '${origin.origin}/sub/fixture_token'},
      'nodes': [
        {'name': '马来西亚 (AWS ap-southeast-5)'},
      ],
    }, origin);
    expect(account.nodes.single.longitude, 101.69);
    expect(account.nodes.single.latitude, 3.14);
  });
}
