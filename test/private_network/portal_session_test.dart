import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/portal_session.dart';

class FakeGateway implements PortalGateway {
  final calls = <String>[];
  bool failClear = false;
  bool failSync = false;
  @override
  Future<void> stopTunnel() async {
    calls.add('stop');
  }

  @override
  Future<void> clearProfiles() async {
    calls.add('clear');
    if (failClear) throw StateError('fixture-clear-failure');
  }

  @override
  Future<void> sync(Uri subscription) async {
    calls.add('sync');
    if (failSync) throw StateError('fixture-sync-failure');
  }
}

class FakeApi implements PortalApi {
  final calls = <String>[];
  bool expired = false;
  bool failLogout = false;
  int? remainingDays;
  Completer<String>? pendingLogin;
  @override
  final origin = Uri.parse('https://vpn.example.com');
  @override
  Future<void> register(String email, String password, String confirmation) async {
    calls.add('register');
  }

  @override
  Future<String> login(String email, String password) async {
    calls.add('login');
    return pendingLogin?.future ?? Future.value('fixture-session');
  }

  @override
  Future<PortalAccount> me(String token) async {
    calls.add('me');
    if (expired) throw const PortalFailure('expired', unauthorized: true);
    return PortalAccount(
      email: 'test@example.com',
      subscription: Uri.parse('${origin.origin}/sub/fixture_token'),
      notice: null,
      remainingDays: remainingDays,
    );
  }

  @override
  Future<void> logout(String token) async {
    calls.add('logout');
    if (failLogout) throw StateError('fixture-backend-offline');
  }

  @override
  void close() {
    calls.add('close');
  }
}

void main() {
  late FakeGateway gateway;
  late FakeApi api;
  late PortalSession session;
  late List<String> saved;
  setUp(() {
    gateway = FakeGateway();
    api = FakeApi();
    saved = [];
    session = PortalSession(
      gateway: gateway,
      readOrigin: () => null,
      saveOrigin: (value) async {
        saved.add(value);
      },
      apiFactory: (_) => api,
      autoInitialize: false,
    );
  });
  tearDown(() => session.dispose());
  Future<void> login({bool register = false}) => session.authenticate(
    origin: api.origin.origin,
    email: 'test@example.com',
    password: 'fixture-password',
    confirmation: register ? 'fixture-password' : null,
  );

  test('cold start cleans cached credentials before permitting login', () async {
    await login();
    expect(api.calls, isEmpty);
    await session.initialize();
    expect(gateway.calls, ['clear']);
    expect(session.ready, true);
    expect(session.account, isNull);
  });
  test('failed startup cleanup keeps the sign-in gate locked', () async {
    gateway.failClear = true;
    await session.initialize();
    await login();
    expect(session.ready, false);
    expect(api.calls, isEmpty);
    expect(session.message, isNotNull);
  });
  test('registration, login, profile fetch and sync run in order', () async {
    await session.initialize();
    await login(register: true);
    expect(api.calls, ['register', 'login', 'me']);
    expect(gateway.calls, ['clear', 'sync']);
    expect(session.profileReady, true);
    expect(saved, ['https://vpn.example.com']); // Only the non-secret origin is persisted.
  });
  test('expired subscription does not import a profile or enable connection', () async {
    await session.initialize();
    api.remainingDays = 0;
    await login();
    expect(session.account?.remainingDays, 0);
    expect(session.profileReady, false);
    expect(gateway.calls, ['clear', 'clear']);
  });
  test('a failed import leaves connect disabled and supports a later refresh', () async {
    await session.initialize();
    gateway.failSync = true;
    await login();
    expect(session.account, isNotNull);
    expect(session.profileReady, false);
    gateway.failSync = false;
    await session.refresh();
    expect(gateway.calls, ['clear', 'sync', 'stop', 'sync']);
    expect(session.profileReady, true);
  });
  test('an expired backend session stops and purges old account credentials', () async {
    await session.initialize();
    await login();
    api.expired = true;
    await session.refresh();
    expect(gateway.calls, ['clear', 'sync', 'stop', 'clear']);
    expect(session.account, isNull);
    expect(session.profileReady, false);
  });
  test('failed tunnel/profile cleanup prevents claiming logout succeeded', () async {
    await session.initialize();
    await login();
    gateway.failClear = true;
    expect(await session.logout(), false);
    expect(session.account, isNotNull);
    expect(api.calls, isNot(contains('logout')));
    expect(session.message, contains('未退出'));
  });
  test('backend logout failure still clears local credentials and is reported', () async {
    await session.initialize();
    await login();
    api.failLogout = true;
    expect(await session.logout(), true);
    expect(session.account, isNull);
    expect(session.profileReady, false);
    expect(session.message, contains('尚未撤销'));
  });
  test('concurrent submissions cannot switch accounts mid-login', () async {
    await session.initialize();
    api.pendingLogin = Completer<String>();
    final first = login();
    await Future<void>.delayed(Duration.zero);
    await login();
    expect(api.calls.where((call) => call == 'login').length, 1);
    api.pendingLogin!.complete('fixture-session');
    await first;
    expect(session.profileReady, true);
  });
}
