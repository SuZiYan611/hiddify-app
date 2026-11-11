import 'package:hiddify/private_network/private_network_home.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/adaptive_layout/my_adaptive_layout.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/custom_transition.dart';
import 'package:hiddify/core/router/go_router/refresh_listenable.dart';
import 'package:hiddify/features/about/widget/about_page.dart';
import 'package:hiddify/features/app_based_routing/overview/app_list_page.dart';
import 'package:hiddify/features/home/widget/home_page.dart';
import 'package:hiddify/features/intro/widget/intro_page.dart';
import 'package:hiddify/features/log/overview/logs_page.dart';
import 'package:hiddify/features/profile/details/profile_details_page.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_page.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_page.dart';
import 'package:hiddify/features/route_rules/notifier/rule_notifier.dart';
import 'package:hiddify/features/route_rules/overview/generic_list_page.dart';
import 'package:hiddify/features/route_rules/overview/package_names_page.dart';
import 'package:hiddify/features/route_rules/overview/rule_page.dart';
import 'package:hiddify/features/settings/overview/sections/chain_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/dns_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/general_page.dart';
import 'package:hiddify/features/settings/overview/sections/inbound_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/routing_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/tls_tricks_page.dart';
import 'package:hiddify/features/settings/overview/settings_page.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'routing_config_notifier.g.dart';

// each branch in go router has its own focus scope
final branchesScope = <String, FocusScopeNode>{
  'home': FocusScopeNode(),
  'profiles': FocusScopeNode(),
  'settings': FocusScopeNode(),
  'logs': FocusScopeNode(),
  'about': FocusScopeNode(),
};

// when the routing config is not yet initialized, this config is used
final loadingConfig = RoutingConfig(
  routes: <RouteBase>[GoRoute(path: '/home', builder: (context, state) => const Material())],
);

String getNameOfBranch(bool isMobileBreakpoint, bool showProfilesAction, int index) => isMobileBreakpoint
    ? ['home', 'settings'][index]
    : ['home', if (showProfilesAction) 'profiles', 'settings', 'logs', 'about'][index];

int getIndexOfBranch(bool isMobileBreakpoint, bool showProfilesAction, String name) => isMobileBreakpoint
    ? ['home', 'settings'].indexOf(name)
    : ['home', if (showProfilesAction) 'profiles', 'settings', 'logs', 'about'].indexOf(name);

@Riverpod(keepAlive: true)
class RoutingConfigNotifier extends _$RoutingConfigNotifier {
  @override
  RoutingConfig build() {
    final isMobileBreakpoint = ref.watch(isMobileBreakpointProvider);
    final bool showProfilesAction;
    if (isMobileBreakpoint == true) {
      showProfilesAction = false;
    } else {
      showProfilesAction = ref.watch(hasAnyProfileProvider).value ?? false;
    }
    if (isMobileBreakpoint == null) return loadingConfig;
    return RoutingConfig(
      redirect: (_, state) => state.matchedLocation == '/intro' ? '/home' : null,
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) => MyAdaptiveLayout(
            navigationShell: navigationShell,
            isMobileBreakpoint: isMobileBreakpoint,
            showProfilesAction: showProfilesAction,
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'home',
                  path: '/home',
                  builder: (_, _) => FocusScope(node: branchesScope['home'], child: const PrivateNetworkHome()),
                  routes: <GoRoute>[
                    GoRoute(
                      name: 'proxies',
                      path: 'proxies',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.fade, state.pageKey, const ProxiesOverviewPage()),
                    ),
                    if (isMobileBreakpoint)
                      GoRoute(
                        name: 'profileDetails',
                        path: 'profile-details/:id',
                        pageBuilder: (_, state) => customTransition(
                          TransitionType.fade,
                          state.pageKey,
                          ProfileDetailsPage(id: state.pathParameters['id']!),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (showProfilesAction)
              StatefulShellBranch(
                routes: <GoRoute>[
                  GoRoute(
                    name: 'profiles',
                    path: '/profiles',
                    builder: (_, _) => FocusScope(node: branchesScope['profiles'], child: const ProfilesPage()),
                    routes: <GoRoute>[
                      GoRoute(
                        name: 'profileDetails',
                        path: 'profile-details/:id',
                        pageBuilder: (_, state) => customTransition(
                          TransitionType.fade,
                          state.pageKey,
                          ProfileDetailsPage(id: state.pathParameters['id']!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            StatefulShellBranch(
              routes: <GoRoute>[
                GoRoute(
                  name: 'settings',
                  path: '/settings',
                  builder: (_, _) => FocusScope(node: branchesScope['settings'], child: SettingsPage()),
                  routes: <GoRoute>[
                    GoRoute(
                      name: 'general',
                      path: 'general',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, const GeneralPage()),
                    ),
                    GoRoute(
                      name: 'routingOptions',
                      path: 'routing-options',
                      pageBuilder: (_, state) => customTransition(
                        TransitionType.slide,
                        state.pageKey,
                        RoutingOptionsPage(routeRule: state.uri.queryParameters['routeRule']),
                      ),
                      routes: <GoRoute>[
                        GoRoute(
                          name: 'rule',
                          path: 'rule/:orderId',
                          pageBuilder: (_, state) {
                            final orderIdString = state.pathParameters['orderId']!;
                            return customTransition(
                              TransitionType.slide,
                              state.pageKey,
                              RulePage(ruleListOrder: orderIdString != 'new' ? int.tryParse(orderIdString) : null),
                            );
                          },
                          onExit: (context, state) async {
                            final t = ref.read(translationsProvider).requireValue;
                            final orderId = int.tryParse(state.pathParameters['orderId']!);
                            final isRuleEdited = ref.read(IsRuleEditedProvider(orderId));
                            if (orderId != null && isRuleEdited) {
                              await ref.read(ruleNotifierProvider(orderId).notifier).save();
                              ref
                                  .read(inAppNotificationControllerProvider)
                                  .showSuccessToast(t.common.msg.autoSave.success);
                            }
                            return true;
                          },
                          routes: <GoRoute>[
                            GoRoute(
                              name: 'genericList',
                              path: 'generic-list/:ruleEnum',
                              pageBuilder: (_, state) {
                                final orderId = int.tryParse(state.pathParameters['orderId']!);
                                final ruleEnum = RuleEnum.values.byName(state.pathParameters['ruleEnum']!);
                                return customTransition(
                                  TransitionType.slide,
                                  state.pageKey,
                                  GenericListPage(ruleListOrder: orderId, ruleEnum: ruleEnum),
                                );
                              },
                            ),
                            GoRoute(
                              name: 'packageNames',
                              path: 'package-names',
                              pageBuilder: (_, state) => customTransition(
                                TransitionType.slide,
                                state.pageKey,
                                PackageNamesPage(ruleListOrder: int.tryParse(state.pathParameters['orderId']!)),
                              ),
                            ),
                          ],
                        ),
                        GoRoute(
                          name: 'appList',
                          path: 'app-list',
                          pageBuilder: (_, state) =>
                              customTransition(TransitionType.slide, state.pageKey, const AppListPage()),
                        ),
                      ],
                    ),
                    GoRoute(
                      name: 'dnsOptions',
                      path: 'dns-options',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, const DnsOptionsPage()),
                    ),
                    GoRoute(
                      name: 'inboundOptions',
                      path: 'inbound-options',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, const InboundOptionsPage()),
                    ),
                    GoRoute(
                      name: 'tlsTricks',
                      path: 'tls-tricks',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, const TlsTricksPage()),
                    ),
                    GoRoute(
                      name: 'chainOptions',
                      path: 'chain-options',
                      pageBuilder: (_, state) =>
                          customTransition(TransitionType.slide, state.pageKey, const ChainOptionsPage()),
                    ),
                    if (isMobileBreakpoint) ...[
                      GoRoute(
                        name: 'logs',
                        path: 'logs',
                        pageBuilder: (_, state) =>
                            customTransition(TransitionType.slide, state.pageKey, const LogsPage()),
                      ),
                      GoRoute(
                        name: 'about',
                        path: 'about',
                        pageBuilder: (_, state) =>
                            customTransition(TransitionType.slide, state.pageKey, const AboutPage()),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (!isMobileBreakpoint) ...[
              StatefulShellBranch(
                routes: <GoRoute>[
                  GoRoute(
                    name: 'logs',
                    path: '/logs',
                    builder: (_, _) => FocusScope(node: branchesScope['logs'], child: const LogsPage()),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: <GoRoute>[
                  GoRoute(
                    name: 'about',
                    path: '/about',
                    builder: (_, _) => FocusScope(node: branchesScope['about'], child: const AboutPage()),
                  ),
                ],
              ),
            ],
          ],
        ),
        GoRoute(name: 'intro', path: '/intro', builder: (_, _) => const IntroPage()),
      ],
    );
  }
}
