import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final portalSessionProvider = ChangeNotifierProvider<PortalSession>((ref) => PortalSession(
  gateway: HiddifyPortalGateway(ref),
  readOrigin: () => ref.read(sharedPreferencesProvider).requireValue.getString('private_network_origin'),
  saveOrigin: (value) async { await ref.read(sharedPreferencesProvider).requireValue.setString('private_network_origin', value); },
));

abstract interface class PortalGateway {
  Future<void> stopTunnel();
  Future<void> clearProfiles();
  Future<void> sync(Uri subscription);
}

/// V1 deliberately keeps the login token in memory only, never preferences or SQLite.
/// A cold start requires login again. The VPN/profile cache is cleared before sign-in.
class PortalSession extends ChangeNotifier {
  PortalSession({required this.gateway, required this.readOrigin, required this.saveOrigin,
    this.apiFactory = PortalApi.new, bool autoInitialize = true}) {
    if (autoInitialize) scheduleMicrotask(initialize);
  }
  final PortalGateway gateway;
  final String? Function() readOrigin;
  final Future<void> Function(String) saveOrigin;
  final PortalApi Function(String) apiFactory;
  static const profileName = '私人网络 · 账户订阅';
  PortalApi? _api;
  String? _token;
  PortalAccount? account;
  String endpoint = const String.fromEnvironment('PORTAL_BASE_URL');
  String? message;
  bool busy = true;
  bool ready = false;
  bool profileReady = false;
  bool _disposed = false;

  void _changed() { if (!_disposed) notifyListeners(); }

  Future<void> initialize() async {
    if (!busy) busy = true;
    message = null;
    _changed();
    try {
      final saved = readOrigin();
      if (saved != null) endpoint = saved;
      await _clearProfiles();
      ready = true;
    } catch (_) {
      message = '无法清理上次的连接，请重试后再登录。';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _stopTunnel() async {
    await gateway.stopTunnel();
  }

  Future<void> _clearProfiles() async {
    await gateway.clearProfiles();
    profileReady = false;
  }

  Future<void> authenticate({required String origin, required String email,
    required String password, String? confirmation}) async {
    if (busy || !ready || account != null) return;
    busy = true;
    message = null;
    _changed();
    try {
      final api = apiFactory(origin);
      _api?.close();
      _api = api;
      endpoint = api.origin.origin;
      await saveOrigin(endpoint);
      if (confirmation != null) await api.register(email, password, confirmation);
      _token = await api.login(email, password);
      account = await api.me(_token!);
      await _syncProfile();
    } on PortalFailure catch (error) {
      message = error.message;
    } catch (_) {
      // The core error is surfaced as an error state, never as connected or a fake node.
      message = '订阅处理失败，请检查后台节点配置后重试。';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _syncProfile() async {
    final user = account;
    if (user == null) return;
    profileReady = false;
    await gateway.sync(user.subscription);
    profileReady = true;
  }

  Future<void> refresh() async {
    if (busy || _token == null || _api == null) return;
    busy = true;
    message = null;
    _changed();
    try {
      // Always stop first: an expired account must not retain a previous tunnel.
      await _stopTunnel();
      account = await _api!.me(_token!);
      await _syncProfile();
    } on PortalFailure catch (error) {
      profileReady = false;
      message = error.message;
      if (error.unauthorized) {
        await _clearProfiles();
        account = null;
        _token = null;
      }
    } catch (_) {
      profileReady = false;
      message = '订阅更新失败，请检查网络后重试。';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<bool> logout() async {
    if (busy) return false;
    busy = true;
    message = null;
    _changed();
    try {
      await _clearProfiles();
      var revoked = true;
      if (_api != null && _token != null) {
        try { await _api!.logout(_token!); } catch (_) { revoked = false; }
      }
      account = null;
      _token = null;
      _api?.close();
      _api = null;
      if (!revoked) message = '已在本机退出；后台暂时无法访问，服务器会话尚未撤销。';
      return true;
    } catch (_) {
      message = '连接或订阅尚未清理完成，未退出账户，请重试。';
      return false;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token = null;
    _api?.close();
    super.dispose();
  }
}

class HiddifyPortalGateway implements PortalGateway {
  HiddifyPortalGateway(this.ref);
  final Ref ref;

  @override
  Future<void> stopTunnel() async {
    await ref.read(Preferences.startedByUser.notifier).update(false);
    await ref.read(connectionNotifierProvider.notifier).abortConnection();
    final repository = ref.read(connectionRepositoryProvider);
    await repository.disconnect()
      .getOrElse((_) => throw const PortalFailure('未能断开 VPN，尚未退出，请重试。')).run();
    await repository.watchConnectionStatus().firstWhere((state) => state is Disconnected)
      .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> clearProfiles() async {
    await stopTunnel();
    final repository = await ref.read(profileRepositoryProvider.future);
    final profiles = await repository.watchAll().first.then((value) => value.getOrElse((_) =>
      throw const PortalFailure('无法读取设备上的订阅配置。')));
    for (final profile in profiles) {
      await repository.deleteById(profile.id, profile.active)
        .getOrElse((_) => throw const PortalFailure('无法清理设备上的订阅配置。')).run();
    }
  }

  @override
  Future<void> sync(Uri subscription) async {
    final repository = await ref.read(profileRepositoryProvider.future);
    await repository.upsertRemote(subscription.toString(), userOverride: const UserOverride(name: PortalSession.profileName))
      .getOrElse((_) => throw const PortalFailure('无法导入订阅，请检查后台节点配置后重试。')).run();
    final profiles = await repository.watchAll().first.then((value) => value.getOrElse((_) =>
      throw const PortalFailure('无法读取订阅。')));
    final matches = profiles.whereType<RemoteProfileEntity>().where((profile) => profile.url == subscription.toString());
    if (matches.length != 1) throw const PortalFailure('没有找到唯一的账户订阅。');
    await repository.setAsActive(matches.single.id)
      .getOrElse((_) => throw const PortalFailure('无法启用账户订阅。')).run();
  }
}
