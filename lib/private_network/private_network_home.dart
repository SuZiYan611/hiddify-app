import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/app_based_routing/data/selected_data_provider.dart';
import 'package:hiddify/features/app_based_routing/overview/app_based_routing_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart' show OutboundInfo;
import 'package:hiddify/private_network/network_globe.dart';
import 'package:hiddify/private_network/portal_account_page.dart';
import 'package:hiddify/private_network/portal_gate.dart';
import 'package:hiddify/private_network/portal_nodes_sheet.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PrivateNetworkHome extends ConsumerStatefulWidget {
  const PrivateNetworkHome({super.key});
  @override
  ConsumerState<PrivateNetworkHome> createState() => _PrivateNetworkHomeState();
}

class _PrivateNetworkHomeState extends ConsumerState<PrivateNetworkHome> {
  final _pageController = PageController();
  final _verticalPageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    _verticalPageController.dispose();
    super.dispose();
  }

  Future<void> _showRoutingPage() =>
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  Future<void> _showConnectionPage() =>
      _pageController.animateToPage(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  Future<void> _showDetailsPage() =>
      _verticalPageController.animateToPage(1, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

  Future<void> _showOverviewPage() =>
      _verticalPageController.animateToPage(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);

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
    final server = ref.watch(activeProxyCardProvider)?.server;
    final nodeName = server != null && !server.isGroup ? server.name : '正在识别节点';
    final nodeDelay = server?.urlTestDelay ?? 0;
    final running = status?.isRunning ?? false;
    final transitioning = status is Connecting || status is HotReloading;
    final actionLabel = transitioning
        ? '取消连接'
        : running
        ? '断开连接'
        : '连接 GBM';
    final canTap =
        !session.busy &&
        status is! Disconnecting &&
        !connection.isLoading &&
        ((running || transitioning) || (session.profileReady && ownProfile));
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            PageView(
              controller: _verticalPageController,
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ConnectionOverview(
                  account: account,
                  nodeName: nodeName,
                  nodeDelay: nodeDelay,
                  running: running,
                  transitioning: transitioning,
                  canTap: canTap,
                  actionLabel: actionLabel,
                  onToggle: _toggle,
                  onOpenRouting: _showRoutingPage,
                  onOpenDetails: _showDetailsPage,
                ),
                _ConnectionDetails(
                  account: account,
                  session: session,
                  running: running,
                  proxy: proxy,
                  onBack: _showOverviewPage,
                  onOpenRouting: _showRoutingPage,
                ),
              ],
            ),
            _AppRoutingPage(onBack: _showConnectionPage),
          ],
        ),
      ),
    );
  }
}

class _ConnectionOverview extends StatelessWidget {
  const _ConnectionOverview({
    required this.account,
    required this.nodeName,
    required this.nodeDelay,
    required this.running,
    required this.transitioning,
    required this.canTap,
    required this.actionLabel,
    required this.onToggle,
    required this.onOpenRouting,
    required this.onOpenDetails,
  });
  final PortalAccount? account;
  final String nodeName;
  final int nodeDelay;
  final bool running;
  final bool transitioning;
  final bool canTap;
  final String actionLabel;
  final VoidCallback onToggle;
  final VoidCallback onOpenRouting;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) => _PageGesture(
    onLeft: onOpenRouting,
    onVertical: onOpenDetails,
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: NetworkPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: NetworkGlobe(nodes: account?.nodes ?? const []),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Semantics(
                          button: true,
                          label: actionLabel,
                          child: Material(
                            color: canTap ? const Color(0xff111111) : const Color(0xff777777),
                            borderRadius: BorderRadius.circular(32),
                            child: InkWell(
                              onTap: canTap ? onToggle : null,
                              borderRadius: BorderRadius.circular(32),
                              child: SizedBox(
                                height: 58,
                                width: double.infinity,
                                child: running
                                    ? Row(
                                        children: [
                                          const SizedBox(width: 20),
                                          const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 22),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              nodeName.isEmpty ? '已连接' : nodeName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.left,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _NodeLatency(delay: nodeDelay),
                                          const SizedBox(width: 20),
                                        ],
                                      )
                                    : Center(
                                        child: Icon(
                                          transitioning ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionDetails extends StatelessWidget {
  const _ConnectionDetails({
    required this.account,
    required this.session,
    required this.running,
    required this.proxy,
    required this.onBack,
    required this.onOpenRouting,
  });
  final PortalAccount? account;
  final PortalSession session;
  final bool running;
  final OutboundInfo? proxy;
  final VoidCallback onBack;
  final VoidCallback onOpenRouting;

  @override
  Widget build(BuildContext context) => _PageGesture(
    onLeft: onOpenRouting,
    onVertical: onBack,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(onPressed: () => context.go('/settings'), icon: const Icon(Icons.settings_outlined)),
              IconButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortalAccountPage())),
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
          NetworkPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('网络节点')),
                    TextButton(
                      onPressed: session.busy
                          ? null
                          : () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => const PortalNodesSheet(),
                            ),
                      child: const Text('选择节点'),
                    ),
                  ],
                ),
                Text(session.profileReady ? '已导入 ${account?.nodeNames.length ?? 0} 个账户节点' : '账户节点尚未就绪'),
                const SizedBox(height: 8),
                const Text('延迟可在节点列表中测试'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          NetworkPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('我的订阅', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 10),
                Text(
                  account?.remainingDays == 0
                      ? '订阅已到期，暂不可连接'
                      : session.profileReady
                      ? '账户订阅已就绪'
                      : '账户订阅待更新',
                ),
                const SizedBox(height: 8),
                const Text('订阅来自你的账户，更新时会先断开当前连接。'),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: session.busy ? null : session.refresh,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('更新订阅'),
                ),
              ],
            ),
          ),
          if (session.message != null) PortalMessage(session.message!),
          if (account?.notice != null) PortalMessage(account!.notice!),
        ],
      ),
    ),
  );
}

class _AppRoutingPage extends ConsumerStatefulWidget {
  const _AppRoutingPage({required this.onBack});
  final VoidCallback onBack;
  @override
  ConsumerState<_AppRoutingPage> createState() => _AppRoutingPageState();
}

class _AppRoutingPageState extends ConsumerState<_AppRoutingPage> {
  bool _applying = false;
  Future<void> _applyChinaDirectList() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      const base = 'https://raw.githubusercontent.com/mnixry/direct-android-ruleset/rules/@Merged';
      final client = ref.read(httpClientProvider);
      final responses = await Future.wait([
        client.get<String>('$base/APP.mutated.yaml'),
        client.get<String>('$base/GAME.mutated.yaml'),
      ]);
      final yaml = responses.map((r) => r.data ?? '').join('\n');
      final packages = RegExp(
        r'^\s*-\s*PROCESS-NAME,([^,#\s]+)',
        multiLine: true,
      ).allMatches(yaml).map((m) => m.group(1)!.trim()).toSet();
      if (packages.isEmpty) throw const FormatException('Empty app list');
      await ref.read(appProxyDataSourceProvider).applyAutoSelection(autoList: packages, mode: AppProxyMode.exclude);
      await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
      await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
      await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
      await ref.read(appBasedRoutingProvider.future);
      await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已载入 ${packages.length} 个大陆应用直连规则，下次连接时生效。')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('应用分流设置失败，请重试。')));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageGesture(
      onRight: widget.onBack,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: NetworkPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.apps_rounded, size: 42),
                        const SizedBox(height: 16),
                        const Text(
                          '应用分流',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '选中的中国大陆应用直连；未选中的应用（包括 Google 服务）继续走 VPN。名单可手动增删。',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _applying ? null : _applyChinaDirectList,
                          icon: _applying
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.download_rounded),
                          label: const Text('载入大陆直连名单'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
                            await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
                            await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
                            await ref.read(appBasedRoutingProvider.future);
                            await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
                            if (context.mounted) context.go('/settings/routing-options/app-list');
                          },
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('手动管理直连应用'),
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkPanel extends StatelessWidget {
  const NetworkPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: child,
  );
}

class _NodeLatency extends StatelessWidget {
  const _NodeLatency({required this.delay});
  final int delay;
  @override
  Widget build(BuildContext context) {
    final pending = delay == 0;
    final timeout = delay >= 65000;
    final color = pending
        ? Colors.grey
        : timeout || delay >= 300
        ? const Color(0xffef5350)
        : delay >= 150
        ? const Color(0xffffa726)
        : const Color(0xff66bb6a);
    final bars = pending || timeout
        ? 0
        : delay >= 300
        ? 1
        : delay >= 150
        ? 2
        : 4;
    return Semantics(
      label: pending
          ? '延迟待测'
          : timeout
          ? '延迟测试超时'
          : '节点延迟 $delay 毫秒',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 2),
                    width: 3,
                    height: 5 + i * 4,
                    decoration: BoxDecoration(
                      color: i < bars ? color : Colors.white24,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            pending
                ? '待测'
                : timeout
                ? '超时'
                : '$delay ms',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PageGesture extends StatefulWidget {
  const _PageGesture({required this.child, this.onLeft, this.onRight, this.onVertical});
  final Widget child;
  final VoidCallback? onLeft, onRight, onVertical;
  @override
  State<_PageGesture> createState() => _PageGestureState();
}

class _PageGestureState extends State<_PageGesture> {
  Offset _distance = Offset.zero;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanDown: (_) => _distance = Offset.zero,
    onPanUpdate: (event) => _distance += event.delta,
    onPanEnd: (_) {
      if (_distance.distance < 28) return;
      if (_distance.dx.abs() > _distance.dy.abs()) {
        if (_distance.dx < 0)
          widget.onLeft?.call();
        else
          widget.onRight?.call();
      } else {
        widget.onVertical?.call();
      }
    },
    child: widget.child,
  );
}
