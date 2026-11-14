import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/private_network/payment_sheet.dart';
import 'package:hiddify/private_network/portal_api.dart';
import 'package:hiddify/private_network/private_network_theme.dart';

void main() {
  final fakeOrder = RechargeOrder(
    orderNo: 'GBM15951234567890124837',
    amountMyr: 10.0,
    planName: '100GB 高速月包',
    recipientName: 'GBM Network',
    recipientPhone: '+601100000000',
    qrPayload: 'https://toyyibpay.com/fake-qr',
    instructions: '安全网关核验',
    paymentUrl: Uri.parse('https://toyyibpay.com/GBM15954837'),
  );

  final fakeManualOrder = RechargeOrder(
    orderNo: 'GBM15951234567890124837',
    amountMyr: 10.0,
    planName: '100GB 高速月包',
    recipientName: 'GBM Network',
    recipientPhone: '+601100000000',
    qrPayload: 'https://toyyibpay.com/fake-qr',
    instructions: '手动转账付款后提交核验',
    paymentUrl: null,
  );

  Widget buildTestWidget({
    required Widget child,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? PrivateNetworkTheme.dark() : PrivateNetworkTheme.light(),
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: content!,
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('Package details come from the order instead of fixed monthly values', (tester) async {
    final order = RechargeOrder.fromJson({
      'order_no': 'GBM-different-plan',
      'amount_myr': 25.5,
      'plan_name': '季度套餐',
      'traffic_gb': 250,
      'validity_days': 90,
      'payment_url': 'https://toyyibpay.com/example',
    });
    await tester.pumpWidget(buildTestWidget(child: MonochromePaymentSheet(order: order)));
    expect(find.text('RM 25.50'), findsOneWidget);
    expect(find.text('250 GB 流量'), findsOneWidget);
    expect(find.text('90 天有效'), findsOneWidget);
    expect(find.text('100 GB 流量'), findsNothing);
    expect(find.text('30 天有效'), findsNothing);
  });

  testWidgets('Legacy order displays its plan name without inventing duration or quota', (tester) async {
    await tester.pumpWidget(buildTestWidget(child: MonochromePaymentSheet(order: fakeOrder)));
    expect(find.text(fakeOrder.planName), findsOneWidget);
    expect(find.text('30 天有效'), findsNothing);
    expect(find.text('100 GB 流量'), findsNothing);
  });

  testWidgets('MonochromePaymentSheet renders correctly in light mode', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        child: MonochromePaymentSheet(order: fakeOrder, paymentStatus: 'pending', paymentState: '等待付款'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GBM'), findsOneWidget);
    expect(find.text('续订你的私人网络'), findsOneWidget);
    expect(find.text('简单付款，安心连接'), findsOneWidget);
    expect(find.text('订阅套餐'), findsOneWidget);
    expect(find.text('RM 10'), findsOneWidget);
    expect(find.text(fakeOrder.planName), findsOneWidget);
    expect(find.text('等待付款'), findsOneWidget);
    expect(find.text('订单编号'), findsOneWidget);
    expect(find.text('GBM1595...4837'), findsOneWidget);
    expect(find.text('付款方式'), findsOneWidget);
    expect(find.text('FPX · DuitNow QR'), findsOneWidget);
    expect(find.text('前往付款'), findsOneWidget);
    expect(find.text('刷新付款状态'), findsOneWidget);
    expect(find.text('付款服务由 ToyyibPay 提供'), findsOneWidget);
  });

  testWidgets('MonochromePaymentSheet renders correctly in dark mode', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        brightness: Brightness.dark,
        child: MonochromePaymentSheet(order: fakeOrder, paymentStatus: 'pending', paymentState: '等待付款'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GBM'), findsOneWidget);
    expect(find.text('续订你的私人网络'), findsOneWidget);
    expect(find.text('前往付款'), findsOneWidget);
    expect(find.text('刷新付款状态'), findsOneWidget);
  });

  testWidgets('MonochromePaymentSheet does not overflow at 320px width and 2.0x font scaling', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestWidget(
        size: const Size(320, 700),
        textScale: 2.0,
        child: MonochromePaymentSheet(order: fakeOrder, paymentStatus: 'pending', paymentState: '等待付款'),
      ),
    );
    await tester.pumpAndSettle();

    expect(MediaQuery.textScalerOf(tester.element(find.byType(MonochromePaymentSheet))).scale(10), 20);
    // Verify no overflow error occurred during layout
    expect(tester.takeException(), isNull);
    expect(find.text('GBM'), findsOneWidget);
    expect(find.text('前往付款'), findsOneWidget);
  });

  testWidgets('MonochromePaymentSheet triggers action callbacks properly', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var openedPayment = false;
    var refreshedStatus = false;
    var copiedOrder = false;

    await tester.pumpWidget(
      buildTestWidget(
        size: const Size(400, 1000),
        child: MonochromePaymentSheet(
          order: fakeOrder,
          onOpenPayment: () => openedPayment = true,
          onRefreshStatus: () => refreshedStatus = true,
          onCopyOrderNo: () => copiedOrder = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('前往付款'));
    expect(openedPayment, isTrue);

    final refreshFinder = find.text('刷新付款状态');
    await tester.ensureVisible(refreshFinder);
    await tester.pumpAndSettle();
    await tester.tap(refreshFinder);
    expect(refreshedStatus, isTrue);

    await tester.tap(find.byIcon(Icons.copy_rounded));
    expect(copiedOrder, isTrue);
  });

  testWidgets('MonochromePaymentSheet shows paid and activation_pending states', (tester) async {
    // 1. activation_pending state
    await tester.pumpWidget(
      buildTestWidget(
        child: MonochromePaymentSheet(order: fakeOrder, paymentStatus: 'activation_pending'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已收到付款，正在开通'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byWidgetPredicate((widget) => widget is ElevatedButton).first).onPressed,
      isNull,
    );
    expect(find.text('正在开通订阅'), findsOneWidget);

    // 2. paid state
    await tester.pumpWidget(
      buildTestWidget(
        child: MonochromePaymentSheet(order: fakeOrder, paid: true, paymentStatus: 'paid'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('付款已核实，服务已开通'), findsOneWidget);
    expect(find.text('订阅已开通'), findsOneWidget);
  });

  testWidgets('MonochromePaymentSheet supports manual payment fallback when paymentUrl is null', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var manualConfirmed = false;

    await tester.pumpWidget(
      buildTestWidget(
        size: const Size(400, 1200),
        child: MonochromePaymentSheet(order: fakeManualOrder, onConfirmManual: () => manualConfirmed = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收款人: GBM Network (+601100000000)'), findsOneWidget);
    expect(find.text('FPX · DuitNow QR'), findsNothing);
    expect(find.text('付款服务由 ToyyibPay 提供'), findsNothing);
    expect(find.text('我已付款，提交核实'), findsOneWidget);

    final submitFinder = find.text('我已付款，提交核实');
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    expect(manualConfirmed, isTrue);
  });
}
