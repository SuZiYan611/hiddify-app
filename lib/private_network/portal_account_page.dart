import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PortalAccountPage extends ConsumerStatefulWidget {
  const PortalAccountPage({super.key});

  @override
  ConsumerState<PortalAccountPage> createState() => _PortalAccountPageState();
}

class _PortalAccountPageState extends ConsumerState<PortalAccountPage> {
  bool _loadingOrder = false;

  Future<void> _openRechargeSheet(BuildContext context, PortalSession session) async {
    setState(() => _loadingOrder = true);
    final order = await session.createRechargeOrder();
    if (!context.mounted) return;
    setState(() => _loadingOrder = false);
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(session.message ?? '获取充值订单失败，请检查网络')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RechargeSheet(order: order, session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(portalSessionProvider);
    final account = session.account;

    final usedGb = account?.usedGb ?? 0.0;
    final limitGb = account?.limitGb ?? 100.0;
    final ratio = account?.usageRatio ?? 0.0;
    final remainingDays = account?.remainingDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的账户'),
        actions: [
          IconButton(
            tooltip: '刷新账户状态',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: session.busy ? null : () => session.refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. 用户基本信息卡片
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account?.email ?? '未登录',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                account?.lifetime == true || (remainingDays ?? 0) > 0 ? '已激活' : '未开通',
                                style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              account?.planName ?? 'RM10 / 100GB 月包',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. 流量使用统计卡片
          if (account?.usageKnown != true)
            const Card(
              child: Padding(padding: EdgeInsets.all(20), child: Text('流量统计暂不可用')),
            ),
          if (account?.usageKnown == true)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.data_usage_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('流量使用统计', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Text(
                          '${(ratio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: ratio > 0.9 ? Colors.red : (ratio > 0.75 ? Colors.orange : Colors.blueAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratio > 0.9 ? Colors.red : (ratio > 0.75 ? Colors.orange : Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已用: ${usedGb.toStringAsFixed(2)} GB',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '总量: ${limitGb.toStringAsFixed(0)} GB',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // 3. 订阅有效期与快速充值卡片
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    remainingDays == 0 ? Icons.hourglass_disabled_rounded : Icons.hourglass_bottom_rounded,
                    color: remainingDays == 0 ? Colors.red : Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account?.lifetime == true
                              ? '长期订阅'
                              : remainingDays == null
                              ? '订阅状态待更新'
                              : (remainingDays == 0 ? '订阅已到期' : '剩余 $remainingDays 天'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account?.lifetime == true ? '该账户长期保留订阅权限' : '到期后将暂停连接，充值立享续期',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: (_loadingOrder || session.busy) ? null : () => _openRechargeSheet(context, session),
                    icon: _loadingOrder
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('充值续费'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. 操作与关于
          const Text(
            '设置与支持',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.qr_code_2_rounded),
            title: const Text('订单付款与续费'),
            subtitle: const Text('RM10 · 30天 · 网关核验到账'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () => _openRechargeSheet(context, session),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('开源与许可'),
            subtitle: const Text('基于 Hiddify 深度定制'),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortalLicensesPage())),
          ),
          const SizedBox(height: 20),

          // 5. 退出登录按钮
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.red.shade300),
              foregroundColor: Colors.red.shade700,
            ),
            onPressed: session.busy
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('退出登录？'),
                        content: const Text('将断开当前 VPN 并清除设备上的配置与会话。'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认退出')),
                        ],
                      ),
                    );
                    if (confirmed == true) await session.logout();
                  },
            child: const Text('退出当前账户'),
          ),
          if (session.message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                session.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet({required this.order, required this.session});
  final RechargeOrder order;
  final PortalSession session;

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  bool _confirming = false;
  Timer? _poll;
  String _paymentState = '等待付款';
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    if (widget.order.paymentUrl != null) {
      _poll = Timer.periodic(const Duration(seconds: 8), (_) => _checkPayment());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    if (_confirming || _paid || !mounted) return;
    setState(() => _confirming = true);
    try {
      final status = await widget.session.syncRechargeOrder(widget.order.orderNo);
      if (!mounted) return;
      setState(() {
        _paid = status == 'paid';
        _paymentState = _paid
            ? '付款已核实，订阅已开通'
            : status == 'activation_pending'
            ? '已收到付款，正在开通，请稍后刷新'
            : '尚未确认到账；付款后请稍候刷新';
      });
      if (_paid) _poll?.cancel();
    } catch (_) {
      if (mounted) setState(() => _paymentState = '暂时无法核实付款，请稍后刷新。');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _openPayment() async {
    final uri = widget.order.paymentUrl;
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw StateError('unavailable');
    } catch (_) {
      if (mounted) setState(() => _paymentState = '无法打开付款页，请稍后重试。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RM10 / 100GB 充值', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 12),

          // 核心金额与套餐展示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.planName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('订单号: ${order.orderNo}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
                Text(
                  'RM ${order.amountMyr.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 动态 DuitNow 二维码渲染器
          if (order.qrPayload.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: QrImageView(
                data: order.qrPayload,
                version: QrVersions.auto,
                size: 210,
                padding: const EdgeInsets.all(8),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            order.paymentUrl != null ? '支付服务：ToyyibPay' : '收款人: ${order.recipientName} (${order.recipientPhone})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            order.instructions,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),

          if (order.paymentUrl != null) ...[
            const Text('打开此订单的付款页，选择 DuitNow QR 扫码或银行付款。付款后回到此页查看结果。', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _paid ? null : _openPayment,
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开订单付款页'),
            ),
            TextButton(
              onPressed: _confirming || _paid ? null : _checkPayment,
              child: Text(_confirming ? '正在核实' : '刷新付款结果'),
            ),
            Text(_paymentState, textAlign: TextAlign.center),
          ],

          // 确认付款按钮
          if (order.paymentUrl == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirming
                    ? null
                    : () async {
                        setState(() => _confirming = true);
                        final ok = await widget.session.confirmRechargeOrder(order.orderNo);
                        if (!mounted) return;
                        setState(() => _confirming = false);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(widget.session.message ?? (ok ? '已提交付款确认，等待核实' : '提交失败，请重试'))),
                          );
                        }
                      },
                icon: _confirming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('我已付款，提交核实', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
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
          '本客户端基于 Hiddify 开源项目改编，保留其连接引擎与网络功能。\n\n修改日期：2026-11-13。修改包括账户接入、DuitNow 订阅充值、黑白灰界面、地球动画及 Android 品牌配置。软件按原项目许可提供，不附带担保。',
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
