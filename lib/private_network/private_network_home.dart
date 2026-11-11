import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/private_network/network_globe.dart';
import 'package:hiddify/private_network/portal_account_page.dart';
import 'package:hiddify/private_network/portal_gate.dart';
import 'package:hiddify/private_network/portal_nodes_sheet.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PrivateNetworkHome extends ConsumerStatefulWidget {
  const PrivateNetworkHome({super.key});
  @override
  ConsumerState<PrivateNetworkHome> createState() => _PrivateNetworkHomeState();
}

class _PrivateNetworkHomeState extends ConsumerState<PrivateNetworkHome> {
  Future<void> _toggle() async {
    try {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接操作失败，请查看设置中的诊断日志。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(portalSessionProvider);
    final account = session.account;
    final connection = ref.watch(connectionNotifierProvider);
    final status = connection.valueOrNull;
    final active = ref.watch(activeProfileProvider).valueOrNull;
    final ownProfile = active is RemoteProfileEntity && active.url == account?.subscription.toString();
    final proxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final connected = status is Connected;
    final running = status?.isRunning ?? false;
    final transitioning = status is Connecting || status is HotReloading;
    final actionLabel = transitioning ? '取消连接' : running ? '断开连接' : '连接私人网络';
    final canTap = !session.busy && status is! Disconnecting &&
      !connection.isLoading && ((running || transitioning) || (session.profileReady && ownProfile));
    final statusLabel = switch (status) {
      Connected() => '已连接',
      Connecting() => '正在连接',
      Waiting() => '正在检测网络',
      NoAvailableProxies() => '暂无可用节点',
      Disconnecting() => '正在断开',
      HotReloading() => '正在更新连接',
      Disconnected(:final connectionFailure) => connectionFailure == null ? '尚未连接' : '连接失败',
      null => connection.hasError ? '连接服务异常' : '正在准备',
    };
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('私人网络', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [IconButton(tooltip: '我的账户', icon: const Icon(Icons.person_outline_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortalAccountPage()))),
          const SizedBox(width: 8)]),
      body: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.all(20),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 12),
            Text('世界很大，自在连接。', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('管理你的连接与订阅', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 20),
            NetworkPanel(child: Column(children: [
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: NetworkGlobe(connected: connected)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(connected ? Icons.verified_user_outlined : Icons.shield_outlined, size: 18),
                const SizedBox(width: 8), Text(statusLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              Text(connected ? '连接状态由设备上的 VPN 服务实时提供' : '选择你的网络，开启专属连接',
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: canTap ? _toggle : null,
                icon: Icon(running || transitioning ? Icons.stop_rounded : Icons.power_settings_new_rounded), label: Text(actionLabel))),
            ])),
            const SizedBox(height: 16),
            NetworkPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.hub_outlined, size: 20), const SizedBox(width: 10),
                const Expanded(child: Text('网络节点', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                TextButton(onPressed: session.busy ? null : () => showModalBottomSheet<void>(context: context,
                  isScrollControlled: true, useSafeArea: true, builder: (_) => const PortalNodesSheet()), child: const Text('选择节点'))]),
              const SizedBox(height: 10),
              Text(running && proxy != null && proxy.tag.isNotEmpty ? proxy.name : '连接后查看当前节点',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(running && proxy != null && proxy.urlTestDelay > 0 && proxy.urlTestDelay < 65000
                ? '实测延迟 ${proxy.urlTestDelay} ms' : '延迟尚未测量', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
            ])),
            const SizedBox(height: 16),
            NetworkPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('我的订阅', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              Text(session.profileReady && ownProfile ? '账户订阅已就绪' : '账户订阅待更新'),
              const SizedBox(height: 8),
              Text('订阅来自你的账户，更新时会先断开当前连接。', style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: session.busy ? null : session.refresh,
                icon: const Icon(Icons.sync_rounded, size: 18), label: const Text('更新订阅')),
            ])),
            if (session.message != null) ...[const SizedBox(height: 16), PortalMessage(session.message!)],
            if (account?.notice != null) ...[const SizedBox(height: 16), PortalMessage(account!.notice!)],
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/settings'), child: const Text('网络设置与诊断')),
          ]),
        )),
      )),
    );
  }
}

class NetworkPanel extends StatelessWidget {
  const NetworkPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)), child: child);
}
