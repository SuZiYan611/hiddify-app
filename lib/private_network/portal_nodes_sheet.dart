import 'package:flutter/material.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/model/proxy_entity.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PortalNodesSheet extends ConsumerStatefulWidget {
  const PortalNodesSheet({super.key});
  @override
  ConsumerState<PortalNodesSheet> createState() => _PortalNodesSheetState();
}

class _PortalNodesSheetState extends ConsumerState<PortalNodesSheet> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    try { await operation(); } catch (_) {
      if (mounted) setState(() => _message = '节点操作失败，请检查连接后重试。');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(proxiesOverviewNotifierProvider);
    return SizedBox(height: MediaQuery.sizeOf(context).height * .75,
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), child: Column(children: [
        Row(children: [const Expanded(child: Text('网络节点', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          IconButton(tooltip: '关闭', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Padding(padding: const EdgeInsets.all(12), child: Text(_message!)),
        Expanded(child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('无法读取节点，请检查连接服务。')),
          data: (group) {
            if (group == null || group.items.isEmpty) {
              return const Center(child: Text('请先连接网络，再查看节点和实测延迟。', textAlign: TextAlign.center));
            }
            final items = group.items.where((item) => !item.tag.contains('§hide§')).toList();
            return Column(children: [
              Align(alignment: Alignment.centerRight, child: TextButton.icon(
                onPressed: _busy ? null : () => _run(() async {
                  await ref.read(proxyRepositoryProvider).urlTest(group.tag)
                    .getOrElse((failure) => throw failure).run();
                }), icon: const Icon(Icons.speed, size: 18), label: const Text('测试延迟'))),
              Expanded(child: ListView.separated(itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1), itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = group.selected == item.tag;
                  final delay = item.urlTestDelay;
                  return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(item.nameWithDetour, maxLines: 2),
                    subtitle: Text(item.typeWithoutStatus),
                    trailing: Text(delay > 0 && delay < 65000 ? '$delay ms' : delay == 0 ? '待测试' : '超时'),
                    enabled: !_busy && group.selectable,
                    onTap: () => _run(() async {
                      await ref.read(proxyRepositoryProvider).selectProxy(group.tag, item.tag)
                        .getOrElse((failure) => throw failure).run();
                    }));
                })),
            ]);
          },
        )),
      ])));
  }
}
