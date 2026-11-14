import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hiddify/private_network/portal_account_page.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hiddify/private_network/private_network_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The root authentication and activation gate for the private network.
///
/// Ensures the router's root [Navigator] and [Overlay] remain continuously
/// mounted in [child] (hidden via [Offstage] when unauthenticated), while
/// presenting [PortalSignInPage] inside its own sub-[Navigator] when no
/// authenticated account session exists.
class PortalGate extends ConsumerWidget {
  const PortalGate({required this.child, super.key});

  final Widget child;

  static final GlobalKey<NavigatorState> signInNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'PortalSignInNav');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(portalSessionProvider);
    final isAuthenticated = session.account != null;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // The router's child is kept mounted so routerDelegate, navigatorKey,
        // and root Overlay remain valid throughout app lifecycle.
        FocusScope(
          canRequestFocus: isAuthenticated,
          descendantsAreFocusable: isAuthenticated,
          child: TickerMode(
            enabled: isAuthenticated,
            child: Offstage(
              offstage: !isAuthenticated,
              child: child,
            ),
          ),
        ),

        // Unauthenticated sign-in flow hosted in its own sub-Navigator so that
        // tooltips, text selection magnifier, dialogs, and sheets find their Overlay.
        if (!isAuthenticated)
          Positioned.fill(
            child: Navigator(
              key: signInNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (context) => const PortalSignInPage(),
              ),
            ),
          ),

        // Global busy barrier when critical auth operations are in-flight.
        if (session.busy)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: .85),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

/// A lightweight vector wireframe globe drawn with CustomPainter.
/// Accurately reflects the visual language from the reference design.
class GbmWireframeGlobe extends StatelessWidget {
  const GbmWireframeGlobe({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strokeColor = isDark ? const Color(0xFFF0F0F2) : const Color(0xFF1C1C1E);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GbmWireframeGlobePainter(color: strokeColor),
      ),
    );
  }
}

class _GbmWireframeGlobePainter extends CustomPainter {
  const _GbmWireframeGlobePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.46;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Outer circle
    canvas.drawCircle(center, radius, stroke);

    // Horizontal equator
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      stroke,
    );

    // Vertical prime meridian
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      stroke,
    );

    // Latitude parallels (top & bottom)
    final parallelY = radius * 0.48;
    final parallelHalfWidth = radius * 0.877;
    final topRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - parallelY),
      width: parallelHalfWidth * 2,
      height: parallelY * 0.85,
    );
    canvas.drawOval(topRect, stroke);

    final bottomRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + parallelY),
      width: parallelHalfWidth * 2,
      height: parallelY * 0.85,
    );
    canvas.drawOval(bottomRect, stroke);

    // Curved meridian (longitude ellipse)
    final meridianRect = Rect.fromCenter(
      center: center,
      width: radius * 1.1,
      height: radius * 2,
    );
    canvas.drawOval(meridianRect, stroke);
  }

  @override
  bool shouldRepaint(covariant _GbmWireframeGlobePainter oldDelegate) => color != oldDelegate.color;
}

/// Pure UI form widget representing the sign-in / registration card.
/// Fully testable in isolation without mocking app-wide Riverpod stores.
class GbmSignInCard extends StatelessWidget {
  const GbmSignInCard({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmationController,
    required this.codeController,
    required this.isRegister,
    required this.obscurePassword,
    required this.busy,
    required this.isSendingCode,
    required this.codeCountdownSeconds,
    this.sessionMessage,
    this.codeMessage,
    this.isReady = true,
    required this.onSubmit,
    required this.onToggleRegister,
    required this.onToggleObscure,
    required this.onSendCode,
    required this.onInitialize,
    required this.onOpenLicenses,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final TextEditingController codeController;
  final bool isRegister;
  final bool obscurePassword;
  final bool busy;
  final bool isSendingCode;
  final int codeCountdownSeconds;
  final String? sessionMessage;
  final String? codeMessage;
  final bool isReady;
  final VoidCallback onSubmit;
  final VoidCallback onToggleRegister;
  final VoidCallback onToggleObscure;
  final VoidCallback onSendCode;
  final VoidCallback onInitialize;
  final VoidCallback onOpenLicenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF111111);
    final cardBg = PrivateNetworkTheme.cardBackground(context);
    final inputBg = PrivateNetworkTheme.inputBackground(context);
    final textMuted = PrivateNetworkTheme.textMuted(context);
    final borderLine = PrivateNetworkTheme.borderLine(context);
    final primaryBtnBg = PrivateNetworkTheme.primaryButtonBg(context);
    final primaryBtnFg = PrivateNetworkTheme.primaryButtonFg(context);

    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top brand wordmark
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'GBM',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Hero section: wireframe globe + title + subtitle
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GbmWireframeGlobe(),
                  const SizedBox(height: 18),
                  Text(
                    '你的私人网络',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '登录，连接你的世界',
                    style: TextStyle(
                      fontSize: 15,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Neutral form container card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '邮箱',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: emailController,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintText: '输入邮箱地址',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ink, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      final text = val?.trim() ?? '';
                      if (text.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
                        return '请输入有效邮箱';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    '密码',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passwordController,
                    enabled: !busy,
                    obscureText: obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [if (isRegister) AutofillHints.newPassword else AutofillHints.password],
                    textInputAction: isRegister ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isRegister && !busy) onSubmit();
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintText: '请输入密码',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ink, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        tooltip: obscurePassword ? '显示密码' : '隐藏密码',
                        icon: Icon(
                          obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: textMuted,
                          size: 20,
                        ),
                        onPressed: onToggleObscure,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return '密码至少 6 位';
                      }
                      return null;
                    },
                  ),

                  // Register additional fields: verification code and confirmation password
                  if (isRegister) ...[
                    const SizedBox(height: 14),
                    Text(
                      '邮箱验证码',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: codeController,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: '输入 6 位验证码',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ink, width: 1.5),
                        ),
                        suffixIcon: TextButton(
                          onPressed: busy || isSendingCode || codeCountdownSeconds > 0 ? null : onSendCode,
                          child: Text(
                            isSendingCode
                                ? '发送中'
                                : codeCountdownSeconds > 0
                                    ? '${codeCountdownSeconds}s'
                                    : '获取验证码',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: codeCountdownSeconds > 0 ? textMuted : ink,
                            ),
                          ),
                        ),
                      ),
                      validator: (val) {
                        if (!RegExp(r'^\d{6}$').hasMatch(val?.trim() ?? '')) {
                          return '请输入 6 位验证码';
                        }
                        return null;
                      },
                    ),
                    if (codeMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        codeMessage!,
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      '再次输入密码',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmationController,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!busy) onSubmit();
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: '请再次输入密码',
                        hintStyle: TextStyle(color: textMuted, fontSize: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: ink, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val != passwordController.text) {
                          return '两次输入的密码不一致';
                        }
                        return null;
                      },
                    ),
                  ],

                  if (sessionMessage != null) ...[
                    const SizedBox(height: 14),
                    PortalMessage(sessionMessage!),
                  ],

                  if (!isReady) ...[
                    const SizedBox(height: 14),
                    Text(
                      '正在准备设备上的网络配置…',
                      style: TextStyle(fontSize: 13, color: textMuted),
                    ),
                    const SizedBox(height: 8),
                    if (busy)
                      const LinearProgressIndicator()
                    else
                      OutlinedButton(
                        onPressed: onInitialize,
                        child: const Text('重新准备'),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Single prominent primary action button
            Material(
              color: busy ? textMuted.withValues(alpha: 0.3) : primaryBtnBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : onSubmit,
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryBtnFg),
                            ),
                          )
                        : Text(
                            isRegister ? '立即注册' : '登录',
                            style: TextStyle(
                              color: primaryBtnFg,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Mode toggle sub-link
            Center(
              child: GestureDetector(
                onTap: busy ? null : onToggleRegister,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRegister ? '已有账户？ ' : '还没有账户？ ',
                        style: TextStyle(fontSize: 14, color: textMuted),
                      ),
                      Text(
                        isRegister ? '登录' : '注册',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Footer brand & licenses link
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GBM 私人网络',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: onOpenLicenses,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '开源与许可',
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The stateful controller for the portal sign-in and registration flow.
class PortalSignInPage extends ConsumerStatefulWidget {
  const PortalSignInPage({super.key});

  @override
  ConsumerState<PortalSignInPage> createState() => _PortalSignInPageState();
}

class _PortalSignInPageState extends ConsumerState<PortalSignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  Timer? _codeTimer;
  int _codeSeconds = 0;
  bool _sendingCode = false;
  String? _codeMessage;
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _code.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final session = ref.read(portalSessionProvider);
    await session.authenticate(
      origin: session.endpoint,
      email: _email.text.trim(),
      password: _password.text,
      confirmation: _register ? _confirmation.text : null,
      verificationCode: _register ? _code.text.trim() : null,
    );
    if (mounted && session.account != null) {
      _password.clear();
      _confirmation.clear();
    }
  }

  Future<void> _sendCode() async {
    final emailText = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailText)) {
      setState(() => _codeMessage = '请先输入有效邮箱');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await ref.read(portalSessionProvider).sendRegistrationCode(emailText);
      if (!mounted) return;
      setState(() {
        _codeSeconds = 60;
        _codeMessage = '若邮箱符合注册条件，验证码将发送至邮箱，10分钟内有效。';
      });
      _codeTimer?.cancel();
      _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _codeSeconds <= 1) timer.cancel();
        if (mounted) {
          setState(() => _codeSeconds = (_codeSeconds - 1).clamp(0, 60));
        }
      });
    } catch (_) {
      if (mounted) setState(() => _codeMessage = '暂时无法发送验证码，请稍后重试。');
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(portalSessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 780;
            final minHeight = constraints.hasBoundedHeight
                ? math.max(0.0, constraints.maxHeight - 40)
                : 0.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 20,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: GbmSignInCard(
                      formKey: _form,
                      emailController: _email,
                      passwordController: _password,
                      confirmationController: _confirmation,
                      codeController: _code,
                      isRegister: _register,
                      obscurePassword: _obscure,
                      busy: session.busy,
                      isSendingCode: _sendingCode,
                      codeCountdownSeconds: _codeSeconds,
                      sessionMessage: session.message,
                      codeMessage: _codeMessage,
                      isReady: session.ready,
                      onSubmit: _submit,
                      onToggleRegister: () {
                        setState(() {
                          _register = !_register;
                          _confirmation.clear();
                          session.message = null;
                        });
                      },
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onSendCode: _sendCode,
                      onInitialize: session.initialize,
                      onOpenLicenses: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PortalLicensesPage(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class PortalMessage extends StatelessWidget {
  const PortalMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      );
}
