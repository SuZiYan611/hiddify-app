import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/private_network/portal_gate.dart';
import 'package:hiddify/private_network/private_network_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  Widget buildPureWidget({
    required Widget child,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? PrivateNetworkTheme.dark() : PrivateNetworkTheme.light(),
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
        child: content!,
      ),
      home: Scaffold(body: child),
    );
  }

  group('GbmWireframeGlobe', () {
    testWidgets('renders properly in light and dark mode', (tester) async {
      await tester.pumpWidget(buildPureWidget(child: const Center(child: GbmWireframeGlobe())));
      await tester.pumpAndSettle();
      expect(find.byType(GbmWireframeGlobe), findsOneWidget);

      await tester.pumpWidget(
        buildPureWidget(
          brightness: Brightness.dark,
          child: const Center(child: GbmWireframeGlobe()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GbmWireframeGlobe), findsOneWidget);
    });
  });

  group('GbmSignInCard', () {
    late GlobalKey<FormState> formKey;
    late TextEditingController emailController;
    late TextEditingController passwordController;
    late TextEditingController confirmationController;
    late TextEditingController codeController;

    setUp(() {
      formKey = GlobalKey<FormState>();
      emailController = TextEditingController();
      passwordController = TextEditingController();
      confirmationController = TextEditingController();
      codeController = TextEditingController();
    });

    tearDown(() {
      emailController.dispose();
      passwordController.dispose();
      confirmationController.dispose();
      codeController.dispose();
    });

    testWidgets('renders login mode with brand and controls in light mode', (tester) async {
      var submitted = false;
      var toggledRegister = false;

      await tester.pumpWidget(
        buildPureWidget(
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: false,
              obscurePassword: true,
              busy: false,
              isSendingCode: false,
              codeCountdownSeconds: 0,
              onSubmit: () => submitted = true,
              onToggleRegister: () => toggledRegister = true,
              onToggleObscure: () {},
              onSendCode: () {},
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GBM'), findsOneWidget);
      expect(find.text('你的私人网络'), findsOneWidget);
      expect(find.text('登录，连接你的世界'), findsOneWidget);
      expect(find.text('邮箱'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      expect(find.textContaining('还没有账户？', findRichText: true), findsOneWidget);
      expect(find.text('GBM 私人网络'), findsOneWidget);
      expect(find.text('开源与许可'), findsOneWidget);

      await tester.tap(find.text('登录'));
      expect(submitted, isTrue);

      await tester.ensureVisible(find.textContaining('还没有账户？', findRichText: true));
      await tester.tap(find.textContaining('还没有账户？', findRichText: true));
      expect(toggledRegister, isTrue);
    });

    testWidgets('renders register mode with verification code and countdown', (tester) async {
      var sentCode = false;

      await tester.pumpWidget(
        buildPureWidget(
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: true,
              obscurePassword: true,
              busy: false,
              isSendingCode: false,
              codeCountdownSeconds: 45,
              codeMessage: '验证码已发送至邮箱',
              onSubmit: () {},
              onToggleRegister: () {},
              onToggleObscure: () {},
              onSendCode: () => sentCode = true,
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('邮箱验证码'), findsOneWidget);
      expect(find.text('再次输入密码'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);
      await tester.tap(find.text('45s'));
      expect(sentCode, isFalse);
      expect(find.text('验证码已发送至邮箱'), findsOneWidget);
      expect(find.text('立即注册'), findsOneWidget);
      expect(find.textContaining('已有账户？', findRichText: true), findsOneWidget);
    });

    testWidgets('does not overflow at 320px width and 2.0x font scaling in both modes', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      // 1. Login mode
      await tester.pumpWidget(
        buildPureWidget(
          size: const Size(320, 700),
          textScale: 2.0,
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: false,
              obscurePassword: true,
              busy: false,
              isSendingCode: false,
              codeCountdownSeconds: 0,
              onSubmit: () {},
              onToggleRegister: () {},
              onToggleObscure: () {},
              onSendCode: () {},
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Register mode
      await tester.pumpWidget(
        buildPureWidget(
          size: const Size(320, 700),
          textScale: 2.0,
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: true,
              obscurePassword: true,
              busy: false,
              isSendingCode: false,
              codeCountdownSeconds: 60,
              sessionMessage: '服务配置正在同步中',
              onSubmit: () {},
              onToggleRegister: () {},
              onToggleObscure: () {},
              onSendCode: () {},
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('validation checks invalid email, password length, and mismatch', (tester) async {
      await tester.pumpWidget(
        buildPureWidget(
          size: const Size(400, 1000),
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: true,
              obscurePassword: true,
              busy: false,
              isSendingCode: false,
              codeCountdownSeconds: 0,
              onSubmit: () {
                formKey.currentState!.validate();
              },
              onToggleRegister: () {},
              onToggleObscure: () {},
              onSendCode: () {},
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger validation directly on formKey
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('请输入有效邮箱'), findsOneWidget);
      expect(find.text('密码至少 6 位'), findsOneWidget);
      final codeField = find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller == codeController,
      );
      expect(tester.state<FormFieldState<String>>(codeField).errorText, '请输入 6 位验证码');

      // Fill email and mismatched password
      emailController.text = 'test@example.com';
      passwordController.text = '123456';
      confirmationController.text = '654321';
      codeController.text = '123456';

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('请输入有效邮箱'), findsNothing);
      expect(find.text('两次输入的密码不一致'), findsOneWidget);
    });

    testWidgets('busy state shows progress and disables action button', (tester) async {
      var submitted = false;

      await tester.pumpWidget(
        buildPureWidget(
          child: SingleChildScrollView(
            child: GbmSignInCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              confirmationController: confirmationController,
              codeController: codeController,
              isRegister: false,
              obscurePassword: true,
              busy: true,
              isSendingCode: false,
              codeCountdownSeconds: 0,
              onSubmit: () => submitted = true,
              onToggleRegister: () {},
              onToggleObscure: () {},
              onSendCode: () {},
              onInitialize: () {},
              onOpenLicenses: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(submitted, isFalse);
    });
  });

  group('PortalGate Host Integration with MaterialApp.router builder and SnackBarHost', () {
    testWidgets('hosts PortalGate inside full MaterialApp.router tree without Overlay or RenderFlex errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Authenticated Home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            theme: PrivateNetworkTheme.light(),
            darkTheme: PrivateNetworkTheme.dark(),
            builder: (context, child) {
              child = PortalGate(child: child ?? const SizedBox());
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
                child: SnackBarHost(child: child),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No exception thrown during host mount and layout
      expect(tester.takeException(), isNull);

      // Verify sign in page is rendered in sub-Navigator with active overlay
      expect(find.byType(PortalSignInPage), findsOneWidget);
      final signInContext = tester.element(find.byType(PortalSignInPage));
      expect(Overlay.maybeOf(signInContext), isNotNull);
      expect(MediaQuery.textScalerOf(signInContext).scale(10), 20);
      expect(find.text('GBM'), findsOneWidget);
      expect(find.text('你的私人网络'), findsOneWidget);

      // Verify Authenticated Home is Offstage (0 visible, 1 in tree)
      expect(find.text('Authenticated Home'), findsNothing);
      expect(find.text('Authenticated Home', skipOffstage: false), findsOneWidget);
    });
  });
}
