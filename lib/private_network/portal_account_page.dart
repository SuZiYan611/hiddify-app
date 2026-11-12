import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class PortalAccountPage extends ConsumerWidget {
  const PortalAccountPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(portalSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的账户')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.person_outline_rounded, size: 48),
          const SizedBox(height: 16),
          Text(
            session.account?.email ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: Icon(
                session.account?.remainingDays == 0 ? Icons.hourglass_disabled_rounded : Icons.hourglass_bottom_rounded,
              ),
              title: Text(session.account?.remainingDays == 0 ? '订阅已到期' : '剩余天数'),
              subtitle: Text(
                session.account?.remainingDays == null
                    ? '该账户尚未设置到期时间'
                    : session.account!.remainingDays == 0
                    ? '续订功能准备中，暂不可连接'
                    : '${session.account!.remainingDays} 天',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('账户与隐私', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            '登录后会在这台设备上安全记住账户；你可以随时在本页退出登录。退出时会先断开 VPN 并清理设备上的订阅配置。\n\n订阅由后台提供。',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code_rounded),
            title: const Text('开源与许可'),
            subtitle: const Text('基于 Hiddify 改编'),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortalLicensesPage())),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: session.busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('退出登录？'),
                        content: const Text('将断开当前 VPN，并移除这台设备上的订阅配置。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出登录')),
                        ],
                      ),
                    );
                    if (confirmed == true) await session.logout();
                  },
            child: const Text('退出登录'),
          ),
          if (session.message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(session.message!)),
        ],
      ),
    );
  }
}

class PortalLicensesPage extends StatelessWidget {
  const PortalLicensesPage({super.key});
  static const sourceUrl = String.fromEnvironment('CLIENT_SOURCE_URL');
  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法打开链接。')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('开源与许可')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('GBM', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        const Text(
          '本客户端基于 Hiddify 开源项目改编，保留其连接引擎与网络功能。\n\n修改日期：2026-11-11。修改包括账户接入、订阅同步、黑白灰界面、地球动画及 Android 品牌配置。软件按原项目许可提供，不附带担保。',
          style: TextStyle(height: 1.7),
        ),
        const SizedBox(height: 20),
        if (sourceUrl.isNotEmpty)
          OutlinedButton(onPressed: () => _open(context, sourceUrl), child: const Text('查看本版本源码')),
        TextButton(
          onPressed: () => _open(context, 'https://github.com/hiddify/hiddify-app'),
          child: const Text('Hiddify 原始项目'),
        ),
        TextButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'GBM'),
          child: const Text('第三方组件许可'),
        ),
        const SizedBox(height: 20),
        FutureBuilder<String>(
          future: rootBundle.loadString('assets/private_network/HIDDIFY-LICENSE.md'),
          builder: (context, result) => result.hasError
              ? const Text('许可文件加载失败，请查看原始项目的 LICENSE.md。')
              : SelectableText(result.data ?? '正在加载许可…', style: const TextStyle(fontSize: 12, height: 1.6)),
        ),
      ],
    ),
  );
}
