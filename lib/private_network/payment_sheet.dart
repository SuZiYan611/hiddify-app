import 'package:flutter/material.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentSheetThemeColors {
  const PaymentSheetThemeColors(this.brightness);
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  Color get sheetBackground => isDark ? const Color(0xFF141414) : Colors.white;
  Color get handleColor => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get cardBackground => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F7);
  Color get cardBorder => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get pillBackground => isDark ? const Color(0xFF28282A) : const Color(0xFFECECEE);
  Color get pillBorder => isDark ? const Color(0xFF333336) : const Color(0xFFE2E2E6);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF111111);
  Color get textSecondary => isDark ? const Color(0xFF9E9E9E) : const Color(0xFF666666);
  Color get textMuted => isDark ? const Color(0xFF757575) : const Color(0xFF8E8E93);
  Color get divider => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
  Color get primaryButtonBg => isDark ? Colors.white : const Color(0xFF111111);
  Color get primaryButtonFg => isDark ? const Color(0xFF111111) : Colors.white;
  Color get secondaryButtonBorder => isDark ? const Color(0xFF3E3E42) : const Color(0xFFD1D1D6);
  Color get secondaryButtonFg => isDark ? Colors.white : const Color(0xFF111111);
  Color get successColor => textPrimary;
}

class MonochromePaymentSheet extends StatelessWidget {
  const MonochromePaymentSheet({
    super.key,
    required this.order,
    this.paymentStatus = 'pending',
    this.paymentState = '等待付款',
    this.confirming = false,
    this.paid = false,
    this.onOpenPayment,
    this.onRefreshStatus,
    this.onClose,
    this.onCopyOrderNo,
    this.onConfirmManual,
  });

  final RechargeOrder order;
  final String paymentStatus; // 'pending', 'activation_pending', 'paid', 'failure'
  final String paymentState;
  final bool confirming;
  final bool paid;
  final VoidCallback? onOpenPayment;
  final VoidCallback? onRefreshStatus;
  final VoidCallback? onClose;
  final VoidCallback? onCopyOrderNo;
  final VoidCallback? onConfirmManual;

  String get _amountFormatted {
    final amt = order.amountMyr;
    return amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
  }

  String get _shortOrderNo {
    final no = order.orderNo;
    if (no.length <= 15) return no;
    return '${no.substring(0, 7)}...${no.substring(no.length - 4)}';
  }

  (IconData, Color, String) _resolveStatus(PaymentSheetThemeColors colors) {
    if (paid || paymentStatus == 'paid') {
      return (Icons.check_circle_rounded, colors.successColor, '付款已核实，服务已开通');
    }
    if (paymentStatus == 'activation_pending') {
      return (Icons.sync_rounded, colors.textPrimary, '已收到付款，正在开通');
    }
    if (paymentStatus == 'failure') {
      return (
        Icons.error_outline_rounded,
        const Color(0xFFEF4444),
        paymentState.isNotEmpty ? paymentState : '核验未完成，请重试',
      );
    }
    return (
      Icons.access_time_rounded,
      colors.textSecondary,
      (paymentState.isNotEmpty && paymentState != '等待付款') ? paymentState : '等待付款',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = PaymentSheetThemeColors(theme.brightness);
    final (statusIcon, statusIconColor, statusText) = _resolveStatus(colors);

    return Container(
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部拖拽条
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: colors.handleColor, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 顶部 GBM 品牌字标与关闭按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GBM',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colors.textPrimary,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: '关闭',
                        child: IconButton(
                          onPressed: onClose,
                          icon: Icon(Icons.close_rounded, size: 22, color: colors.textSecondary),
                          tooltip: '关闭',
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 标题区
                  Text(
                    '续订你的私人网络',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text('简单付款，安心连接', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
                  const SizedBox(height: 16),

                  // 套餐卡片 (黑白灰自洽对比度)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '订阅套餐',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'RM $_amountFormatted',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (order.validityDays != null)
                              Text(
                                '/ ${order.validityDays} 天',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: colors.divider, height: 1, thickness: 1),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Text(
                              order.trafficGb == null
                                  ? order.planName
                                  : '${order.trafficGb!.toStringAsFixed(order.trafficGb! % 1 == 0 ? 0 : 1)} GB 流量',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
                            ),
                            if (order.validityDays != null)
                              Text('•', style: TextStyle(fontSize: 14, color: colors.divider)),
                            if (order.validityDays != null)
                              Text(
                                '${order.validityDays} 天有效',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 状态 Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.pillBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.pillBorder),
                    ),
                    child: Row(
                      children: [
                        if (confirming) ...[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.textPrimary),
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Icon(statusIcon, size: 18, color: statusIconColor),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 订单编号行（Wrap 自适应，支持超长订单编号，不溢出，轻点复制）
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        Text('订单编号', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
                        InkWell(
                          onTap: onCopyOrderNo,
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Semantics(
                                  label: '订单编号: ${order.orderNo}',
                                  child: Text(
                                    _shortOrderNo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Semantics(
                                button: true,
                                label: '复制完整订单号',
                                child: Icon(Icons.copy_rounded, size: 16, color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 付款方式行
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        Text('付款方式', style: TextStyle(fontSize: 14, color: colors.textSecondary)),
                        Text(
                          order.paymentUrl != null ? 'FPX · DuitNow QR' : 'DuitNow QR',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 说明文案
                  Text(
                    '• 前往安全付款页完成支付\n• 付款后返回，状态将自动更新',
                    style: TextStyle(fontSize: 13, height: 1.6, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // 按钮区域
                  if (order.paymentUrl != null) ...[
                    // 前往付款主按钮 (12px圆角，反色对比，light黑底白字，dark白底黑字)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryButtonBg,
                          foregroundColor: colors.primaryButtonFg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (paid || paymentStatus == 'paid' || paymentStatus == 'activation_pending')
                            ? null
                            : onOpenPayment,
                        icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            (paid || paymentStatus == 'paid')
                                ? '订阅已开通'
                                : paymentStatus == 'activation_pending'
                                ? '正在开通订阅'
                                : '前往付款',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 刷新付款状态副按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.secondaryButtonFg,
                          side: BorderSide(color: colors.secondaryButtonBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (confirming || paid || paymentStatus == 'paid') ? null : onRefreshStatus,
                        icon: confirming
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colors.secondaryButtonFg),
                              )
                            : const Icon(Icons.refresh_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            confirming ? '正在核实付款' : '刷新付款状态',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 降级旧式 manual 付款支持 (当 paymentUrl == null 时)
                  if (order.paymentUrl == null) ...[
                    if (order.qrPayload.isNotEmpty) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          child: QrImageView(data: order.qrPayload, size: 200, padding: const EdgeInsets.all(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      '收款人: ${order.recipientName} (${order.recipientPhone})',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    if (order.instructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        order.instructions,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primaryButtonBg,
                          foregroundColor: colors.primaryButtonFg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: confirming ? null : onConfirmManual,
                        icon: confirming
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colors.primaryButtonFg),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('我已付款，提交核实', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 官方信用小字
                  Center(
                    child: Text(
                      order.paymentUrl != null ? '付款服务由 ToyyibPay 提供' : '付款后请提交核实',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
