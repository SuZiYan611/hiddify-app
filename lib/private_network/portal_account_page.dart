import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/private_network/payment_sheet.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:hiddify/private_network/payment_sheet.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final usedGb = account?.usedGb ?? 0.0;
    final limitGb = account?.limitGb ?? 100.0;
    final ratio = account?.usageRatio ?? 0.0;
    final remainingDays = account?.remainingDays;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final textMuted = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6E6E73);

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. 用户基本信息卡片（克制黑白灰）
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEEEEEE),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 28,
                      color: isDark ? Colors.white : const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account?.email ?? '未登录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF28282A) : const Color(0xFFEBEBED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isDark ? const Color(0xFF38383A) : const Color(0xFFDCDCE0)),
                              ),
                              child: Text(
                                account?.lifetime == true || (remainingDays ?? 0) > 0 ? '已激活' : '未开通',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF111111),
                                ),
                              ),
                            ),
                            Text(
                              account?.planName ?? 'RM10 / 100GB 月包',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. 流量使用统计卡片（纯净黑白灰指示条）
            if (account?.usageKnown == true)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.data_usage_rounded, size: 18, color: textMuted),
                            const SizedBox(width: 8),
                            const Text('流量使用统计', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '${(ratio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                        valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : const Color(0xFF111111)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已用: ${usedGb.toStringAsFixed(2)} GB',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMuted),
                        ),
                        Text('总量: ${limitGb.toStringAsFixed(0)} GB', style: TextStyle(fontSize: 13, color: textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // 3. 订阅有效期与快速充值卡片
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    remainingDays == 0 ? Icons.hourglass_disabled_rounded : Icons.hourglass_bottom_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF111111),
                    size: 26,
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account?.lifetime == true ? '该账户长期保留订阅权限' : '到期后将暂停连接，充值立享续期',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (_loadingOrder || session.busy) ? null : () => _openRechargeSheet(context, session),
                    child: _loadingOrder
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('充值续费', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. 操作与关于
            Text(
              '服务与信息',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMuted),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.payment_rounded),
                    title: const Text('订单付款与续费'),
                    subtitle: Text('RM10 · 30天 · 网关核验到账', style: TextStyle(color: textMuted)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                    onTap: () => _openRechargeSheet(context, session),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: cardBorder),
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded),
                    title: const Text('开源与第三方许可'),
                    subtitle: Text('核心连接引擎与第三方组件许可', style: TextStyle(color: textMuted)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textMuted),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PortalLicensesPage())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. 退出登录按钮
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: session.busy
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('退出登录？'),
                          content: const Text('将断开当前私人网络并清除设备上的配置与会话。'),
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
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ),
          ],
        ),
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
  String _paymentStatus = 'pending';
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
        _paymentStatus = status;
        _paid = status == 'paid';
        _paymentState = _paid
            ? '付款已核实，订阅已开通'
            : status == 'activation_pending'
            ? '已收到付款，正在开通，请稍后刷新'
            : '尚未确认到账；付款后请稍候刷新';
      });
      if (_paid) _poll?.cancel();
    } catch (_) {
      if (mounted) {
        setState(() {
          _paymentStatus = 'failure';
          _paymentState = '暂时无法核实付款，请稍后刷新。';
        });
      }
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
      if (mounted) {
        setState(() {
          _paymentStatus = 'failure';
          _paymentState = '无法打开付款页，请稍后重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MonochromePaymentSheet(
      order: widget.order,
      paymentStatus: _paymentStatus,
      paymentState: _paymentState,
      confirming: _confirming,
      paid: _paid,
      onOpenPayment: _openPayment,
      onRefreshStatus: _checkPayment,
      onClose: () => Navigator.pop(context),
      onCopyOrderNo: () {
        Clipboard.setData(ClipboardData(text: widget.order.orderNo));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单号已复制到剪贴板'), duration: Duration(seconds: 2)));
      },
      onConfirmManual: () async {
        setState(() => _confirming = true);
        final ok = await widget.session.confirmRechargeOrder(widget.order.orderNo);
        if (!mounted) return;
        setState(() => _confirming = false);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(widget.session.message ?? (ok ? '已提交付款确认，等待核实' : '提交失败，请重试'))));
        }
      },
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
    appBar: AppBar(title: const Text('开源与第三方许可')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('GBM', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
          'GBM 私人网络客户端基于开源技术构建，保留核心连接引擎与网络功能。\n\n本软件按原项目开源许可提供，保留原作者的版权与许可证声明。第三方组件版权归属于各自权利人。',
          style: TextStyle(height: 1.6),
        ),
        const SizedBox(height: 20),
        if (sourceUrl.isNotEmpty)
          OutlinedButton(onPressed: () => _open(context, sourceUrl), child: const Text('查看本版本源码')),
        TextButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'GBM'),
          child: const Text('第三方组件许可清单'),
        ),
        const SizedBox(height: 20),
        const Text('基础连接引擎开源许可证 (HIDDIFY-LICENSE)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<String>(
          future: rootBundle.loadString('assets/private_network/HIDDIFY-LICENSE.md'),
          builder: (context, result) => result.hasError
              ? const Text('许可文件加载失败。')
              : SelectableText(result.data ?? '正在加载许可…', style: const TextStyle(fontSize: 12, height: 1.6)),
        ),
      ],
    ),
  );
}
