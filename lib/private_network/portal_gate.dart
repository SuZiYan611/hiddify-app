import 'package:flutter/material.dart';
import 'package:hiddify/private_network/network_globe.dart';
import 'package:hiddify/private_network/portal_account_page.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PortalGate extends ConsumerWidget {
  const PortalGate({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(portalSessionProvider);
    if (session.account == null) return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const PortalSignInPage()),
    );
    return Stack(children: [
      child,
      if (session.busy) Positioned.fill(child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .85),
        child: const Center(child: CircularProgressIndicator()),
      )),
    ]);
  }
}

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
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _confirmation.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final session = ref.read(portalSessionProvider);
    await session.authenticate(origin: session.endpoint, email: _email.text,
      password: _password.text, confirmation: _register ? _confirmation.text : null);
    if (mounted && session.account != null) {
      _password.clear(); _confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(portalSessionProvider);
    final theme = Theme.of(context);
    final card = Container(
      width: 420,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 24, offset: const Offset(0, 8))]),
      child: AutofillGroup(child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_register ? '创建你的账户' : '欢迎回来', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('登录你的私人网络账户', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 22),
        Row(children: [for (final register in [false, true]) Expanded(child: TextButton(
          onPressed: session.busy ? null : () => setState(() { _register = register; _confirmation.clear(); }),
          style: TextButton.styleFrom(shape: const RoundedRectangleBorder(),
            side: Border(bottom: BorderSide(color: _register == register ? theme.colorScheme.primary : theme.dividerColor, width: 2)).bottom),
          child: Text(register ? '注册新账号' : '用户登录', style: TextStyle(fontWeight: _register == register ? FontWeight.w700 : FontWeight.w400)),
        ))]),
        const SizedBox(height: 22),
        if (session.message != null) ...[
          PortalMessage(session.message!), const SizedBox(height: 16),
        ],
        if (!session.ready) ...[
          const Text('正在准备设备上的网络配置。'), const SizedBox(height: 12),
          if (session.busy) const LinearProgressIndicator()
          else OutlinedButton(onPressed: session.initialize, child: const Text('重新准备')),
        ] else ...[
          TextFormField(controller: _email, enabled: !session.busy,
            decoration: const InputDecoration(labelText: '邮箱', hintText: 'user@example.com'),
            keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next, autocorrect: false,
            validator: (value) => value != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? null : '请输入有效邮箱'),
          const SizedBox(height: 18),
          TextFormField(controller: _password, enabled: !session.busy,
            decoration: InputDecoration(labelText: '密码', hintText: '请输入密码',
              suffixIcon: IconButton(tooltip: _obscure ? '显示密码' : '隐藏密码',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
            obscureText: _obscure, autocorrect: false, enableSuggestions: false,
            autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
            textInputAction: _register ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) { if (!_register && !session.busy) _submit(); },
            validator: (value) => value != null && value.length >= 6 ? null : '密码至少 6 位'),
          if (_register) ...[
            const SizedBox(height: 18),
            TextFormField(controller: _confirmation, enabled: !session.busy,
              decoration: const InputDecoration(labelText: '再次输入密码'), obscureText: true,
              autocorrect: false, enableSuggestions: false, autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value == _password.text ? null : '两次输入的密码不一致',
              onFieldSubmitted: (_) { if (!session.busy) _submit(); }),
          ],
          const SizedBox(height: 14),
          FilledButton(onPressed: session.busy ? null : _submit,
            child: session.busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_register ? '立即注册' : '登录')),
          const SizedBox(height: 16),
          Text('你的连接，只属于你。', textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PortalLicensesPage())), child: const Text('开源与许可')),
        ],
      ]))),
    );
    return Scaffold(body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 780;
      return SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: 24),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100),
          child: wide ? Row(children: [
            const Expanded(child: NetworkGlobe()), const SizedBox(width: 40), Flexible(child: card),
          ]) : Column(children: [
            const Text('私人网络', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 3)),
            const SizedBox(height: 8), const SizedBox(width: 240, height: 220, child: NetworkGlobe()), card,
          ]),
        )),
      );
    })));
  }
}

class PortalMessage extends StatelessWidget {
  const PortalMessage(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: const TextStyle(fontSize: 13, height: 1.6)),
  );
}
