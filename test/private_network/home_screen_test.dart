import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/private_network/portal_session.dart';
import 'package:hiddify/private_network/private_network_home.dart';
import 'package:hiddify/private_network/private_network_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('signed-out home does not initialize connection or routing providers', (tester) async {
    final session = PortalSession(
      gateway: _UnusedGateway(),
      readOrigin: () => null,
      saveOrigin: (_) async {},
      autoInitialize: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [portalSessionProvider.overrideWith((ref) => session)],
        child: const MaterialApp(home: PrivateNetworkHome()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsNothing);
  });

  Widget buildPureWidget({
    required Widget child,
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? PrivateNetworkTheme.dark() : PrivateNetworkTheme.light(),
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: content!,
      ),
      home: Scaffold(body: child),
    );
  }

  group('GbmStatusPill', () {
    testWidgets('maps connection states to accurate status labels and icons', (tester) async {
      // 1. Connecting / transitioning state
      await tester.pumpWidget(
        buildPureWidget(
          child: const Center(
            child: GbmStatusPill(running: false, transitioning: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('连接中'), findsOneWidget);

      // 2. Connected / running state
      await tester.pumpWidget(
        buildPureWidget(
          child: const Center(
            child: GbmStatusPill(running: true, transitioning: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已连接'), findsOneWidget);

      // 3. Disconnecting state
      await tester.pumpWidget(
        buildPureWidget(
          child: const Center(
            child: GbmStatusPill(running: false, transitioning: false, statusName: 'disconnecting'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('断开中'), findsOneWidget);

      // 4. Failed state
      await tester.pumpWidget(
        buildPureWidget(
          child: const Center(
            child: GbmStatusPill(running: false, transitioning: false, statusName: 'failed'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('连接失败'), findsOneWidget);

      // 5. Disconnected default state
      await tester.pumpWidget(
        buildPureWidget(
          child: const Center(
            child: GbmStatusPill(running: false, transitioning: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('未连接'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark mode', (tester) async {
      await tester.pumpWidget(
        buildPureWidget(
          brightness: Brightness.dark,
          child: const Center(
            child: GbmStatusPill(running: false, transitioning: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('未连接'), findsOneWidget);
    });
  });

  group('GbmNodeCard', () {
    testWidgets('displays empty state fallback and real node name', (tester) async {
      var tapped = false;

      // 1. Empty state
      await tester.pumpWidget(
        buildPureWidget(
          child: Center(
            child: GbmNodeCard(
              nodeName: '',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前节点'), findsOneWidget);
      expect(find.text('选择可用节点'), findsOneWidget);

      await tester.tap(find.byType(GbmNodeCard));
      expect(tapped, isTrue);

      // 2. Real node name with latency
      await tester.pumpWidget(
        buildPureWidget(
          child: Center(
            child: GbmNodeCard(
              nodeName: '新加坡 01 高速专线',
              nodeDelay: 42,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前节点'), findsOneWidget);
      expect(find.text('新加坡 01 高速专线'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '节点延迟 42 毫秒'), findsOneWidget);
    });
  });

  group('GbmBottomBar', () {
    testWidgets('renders navigation tabs and triggers account callback', (tester) async {
      var accountOpened = false;

      await tester.pumpWidget(
        buildPureWidget(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GbmBottomBar(
              onOpenAccount: () => accountOpened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('连接'), findsOneWidget);
      expect(find.text('账户'), findsOneWidget);

      await tester.tap(find.text('账户'));
      expect(accountOpened, isTrue);
    });
  });

  group('Home UI Responsiveness', () {
    testWidgets('does not overflow at 320px width and 2.0x font scaling in light and dark mode', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      // Light mode test with status pill, node card, connect button and bottom bar
      await tester.pumpWidget(
        buildPureWidget(
          size: const Size(320, 700),
          textScale: 2.0,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GbmStatusPill(running: false, transitioning: false),
                const SizedBox(height: 12),
                GbmNodeCard(
                  nodeName: '香港 01 超级专线节点',
                  nodeDelay: 35,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                GbmBottomBar(onOpenAccount: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dark mode test
      await tester.pumpWidget(
        buildPureWidget(
          brightness: Brightness.dark,
          size: const Size(320, 700),
          textScale: 2.0,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GbmStatusPill(running: true, transitioning: false),
                const SizedBox(height: 12),
                GbmNodeCard(
                  nodeName: '日本东京 02 专线',
                  nodeDelay: 85,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                GbmBottomBar(onOpenAccount: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

class _UnusedGateway implements PortalGateway {
  @override
  Future<void> stopTunnel() async => throw StateError('Unexpected gateway operation');
  @override
  Future<void> clearProfiles() async => throw StateError('Unexpected gateway operation');
  @override
  Future<void> sync(Uri subscription) async => throw StateError('Unexpected gateway operation');
}
