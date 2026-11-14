import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/app_based_routing/overview/app_based_routing_notifier.dart';
import 'package:hiddify/features/app_based_routing/overview/app_list_page.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart' show OutboundInfo;
import 'package:hiddify/private_network/gbm_china_bypass_defaults.dart';
import 'package:hiddify/private_network/gbm_update_settings.dart';
import 'package:hiddify/private_network/network_globe.dart';
import 'package:hiddify/private_network/portal_account_page.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/portal_gate.dart';
import 'package:hiddify/private_network/portal_nodes_sheet.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hiddify/private_network/private_network_theme.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GbmChinaBypassHelper.ensureDefaultEnabled(ref);
    });
  }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接操作失败，请查看设置中的诊断日志。')));
      }
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

    return Stack(
      children: [
        const GbmUpdateSettings(watcher: true),
        Scaffold(
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
        ),
      ],
    );
  }
}

class GbmStatusPill extends StatelessWidget {
  const GbmStatusPill({
    super.key,
    required this.running,
    required this.transitioning,
    this.statusName,
  });

  final bool running;
  final bool transitioning;
  final String? statusName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = PrivateNetworkTheme.cardBackground(context);
    final borderLine = PrivateNetworkTheme.borderLine(context);
    final textMuted = PrivateNetworkTheme.textMuted(context);
    final ink = theme.brightness == Brightness.dark ? const Color(0xFFF4F4F4) : const Color(0xFF111111);

    final String text;
    final Widget icon;

    if (transitioning) {
      text = '连接中';
      icon = const Icon(Icons.radio_button_checked, size: 10, color: Color(0xFFF59E0B));
    } else if (running) {
      text = '已连接';
      icon = const Icon(Icons.circle, size: 9, color: Color(0xFF10B981));
    } else if (statusName == 'disconnecting') {
      text = '断开中';
      icon = Icon(Icons.radio_button_unchecked, size: 10, color: textMuted);
    } else if (statusName == 'failed') {
      text = '连接失败';
      icon = const Icon(Icons.error_outline, size: 10, color: Color(0xFFEF4444));
    } else {
      text = '未连接';
      icon = Icon(Icons.radio_button_unchecked, size: 10, color: textMuted);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class GbmNodeCard extends StatelessWidget {
  const GbmNodeCard({
    super.key,
    required this.nodeName,
    this.nodeDelay = 0,
    required this.onTap,
  });

  final String nodeName;
  final int nodeDelay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = PrivateNetworkTheme.cardBackground(context);
    final borderLine = PrivateNetworkTheme.borderLine(context);
    final textMuted = PrivateNetworkTheme.textMuted(context);
    final ink = theme.brightness == Brightness.dark ? const Color(0xFFF4F4F4) : const Color(0xFF111111);
    final display = (nodeName.isEmpty || nodeName == '正在识别节点') ? '选择可用节点' : nodeName;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '当前节点',
                      style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                    ),
                  ],
                ),
              ),
              if (nodeDelay > 0) ...[
                const SizedBox(width: 8),
                _NodeLatency(delay: nodeDelay),
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class GbmBottomBar extends StatelessWidget {
  const GbmBottomBar({
    super.key,
    required this.onOpenAccount,
  });

  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF111111);
    final textMuted = PrivateNetworkTheme.textMuted(context);
    final borderLine = PrivateNetworkTheme.borderLine(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: borderLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {},
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power_settings_new_rounded, size: 20, color: ink),
                  const SizedBox(height: 2),
                  Text('连接', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onOpenAccount,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_outline_rounded, size: 20, color: textMuted),
                  const SizedBox(height: 2),
                  Text('账户', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionOverview extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final chinaBypass = ref.watch(Preferences.perAppProxyEnabled);
    final session = ref.watch(portalSessionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = PrivateNetworkTheme.textMuted(context);
    final ink = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF111111);
    final primaryBtnBg = PrivateNetworkTheme.primaryButtonBg(context);
    final primaryBtnFg = PrivateNetworkTheme.primaryButtonFg(context);
    final disabledBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFDCDCE0);

    return _PageGesture(
      onLeft: onOpenRouting,
      onVertical: onOpenDetails,
      child: Column(
        children: [
          // Top bar with GBM wordmark and action shortcuts
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GBM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: ink,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_outline_rounded),
                      tooltip: '我的账户',
                      color: ink,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PortalAccountPage()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: '设置',
                      color: ink,
                      onPressed: () => context.go('/settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header title & real connection status pill
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '连接你的世界',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GbmStatusPill(
                              running: running,
                              transitioning: transitioning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Interactive 3D Canvas Globe
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                          child: NetworkGlobe(
                            nodes: account?.nodes ?? const [],
                            onNodeSelected: (index) async {
                              final nodes = account?.nodes;
                              if (nodes != null && index >= 0 && index < nodes.length) {
                                final targetName = nodes[index].name.toLowerCase();
                                final group = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
                                if (group != null) {
                                  for (final item in group.items) {
                                    if (item.name.toLowerCase().contains(targetName) ||
                                        targetName.contains(item.name.toLowerCase())) {
                                      try {
                                        await ref.read(proxyRepositoryProvider).selectProxy(group.tag, item.tag).run();
                                      } catch (_) {}
                                      break;
                                    }
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Current Node Selection Card
                      GbmNodeCard(
                        nodeName: nodeName,
                        nodeDelay: nodeDelay,
                        onTap: session.busy
                            ? null
                            : () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => const PortalNodesSheet(),
                                ),
                      ),
                      const SizedBox(height: 14),

                      // Primary Connect Action Button
                      Material(
                        color: canTap ? primaryBtnBg : disabledBg,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: canTap ? onToggle : null,
                          child: SizedBox(
                            height: 52,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.power_settings_new_rounded,
                                  color: canTap ? primaryBtnFg : textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  actionLabel,
                                  style: TextStyle(
                                    color: canTap ? primaryBtnFg : textMuted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Hint text below button
                      Center(
                        child: Text(
                          '旋转地球，选择你的节点',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // China bypass and secondary shortcuts
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: Icon(
                                chinaBypass ? Icons.check_circle_rounded : Icons.do_not_disturb_on_rounded,
                                size: 15,
                                color: chinaBypass ? const Color(0xFF10B981) : textMuted,
                              ),
                              label: Text(
                                chinaBypass ? '大陆分流: 开' : '大陆分流: 关',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: chinaBypass ? null : textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              onPressed: () async {
                                await GbmChinaBypassHelper.toggleEnabled(ref, !chinaBypass);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
                                      content: Text(
                                        !chinaBypass
                                            ? '已开启中国应用分流直连（微信、淘宝等不走 VPN）'
                                            : '已关闭分流直连（全部流量走 VPN）',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.tune_rounded, size: 15),
                              label: const Text('应用分流', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              onPressed: onOpenRouting,
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.arrow_downward_rounded, size: 15),
                              label: const Text('详细订阅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              onPressed: onOpenDetails,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom navigation bar
          GbmBottomBar(
            onOpenAccount: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PortalAccountPage()),
            ),
          ),
        ],
      ),
    );
  }
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
                  account == null
                      ? '未登录账户'
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

  Future<void> _syncOnline() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final count = await GbmChinaBypassHelper.syncFromRemote(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已从云端同步 $count 个大陆应用直连规则。')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('云端同步失败，已保留现有或内置白名单。')));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _restoreDefaults() async {
    if (_applying) return;
    setState(() => _applying = true);
    try {
      final count = await GbmChinaBypassHelper.restoreDefaultList(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已恢复内置默认大陆白名单（共 $count 款核心应用）。')));
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(Preferences.perAppProxyEnabled);
    final activeCount = ref.watch(Preferences.excludeApps).length;

    return _PageGesture(
      onRight: widget.onBack,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: widget.onBack, tooltip: '返回'),
              const Expanded(
                child: Text('应用分流设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      NetworkPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: enabled
                                        ? const Color(0xff10b981).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                                    color: enabled ? const Color(0xff10b981) : Colors.grey,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '绕过中国大陆应用',
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        enabled ? '分流直连已开启' : '分流直连已关闭',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: enabled ? const Color(0xff10b981) : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: enabled,
                                  onChanged: (val) async {
                                    await GbmChinaBypassHelper.toggleEnabled(ref, val);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              enabled
                                  ? '已开启直连分流：选中的国内应用（微信、支付宝、淘宝、抖音、B站等）直连不消耗代理流量；Google、YouTube、Twitter、ChatGPT 等外网走加密 VPN。'
                                  : '已关闭直连分流：所有手机网络流量均通过海外 VPN 节点代理。',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                            if (enabled) ...[
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.apps_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '当前已生效直连应用: $activeCount 款',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      NetworkPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('应用名单管理', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
                                await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
                                await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
                                await ref.read(appBasedRoutingProvider.future);
                                await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                  ).push(MaterialPageRoute<void>(builder: (_) => const AppListPage()));
                                }
                              },
                              icon: const Icon(Icons.playlist_add_check_rounded),
                              label: const Text('手动增删直连应用 (勾选/取消)'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _applying ? null : _syncOnline,
                              icon: _applying
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_download_outlined),
                              label: const Text('从云端更新最新大陆应用库'),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _applying ? null : _restoreDefaults,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('恢复内置默认推荐白名单'),
                            ),
                          ],
                        ),
                      ),
                    ],
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
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onVertical;
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
        if (_distance.dx < 0) {
          widget.onLeft?.call();
        } else {
          widget.onRight?.call();
        }
      } else {
        widget.onVertical?.call();
      }
    },
    child: widget.child,
  );
}
