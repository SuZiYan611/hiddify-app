import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _currentTag = String.fromEnvironment('GBM_RELEASE_TAG', defaultValue: 'private-network-v0.1.0-test3');
const _preference = 'gbm_auto_check_updates';

/// Settings and the startup watcher use the same persisted preference.
class GbmUpdateSettings extends StatefulWidget {
  const GbmUpdateSettings({super.key, this.watcher = false});
  final bool watcher;
  @override
  State<GbmUpdateSettings> createState() => _GbmUpdateSettingsState();
}

class _GbmUpdateSettingsState extends State<GbmUpdateSettings> {
  static bool _startupChecked = false;
  bool _enabled = true;
  bool _busy = false;
  String _message = '当前版本：$_currentTag';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _enabled = prefs.getBool(_preference) ?? true);
    if (widget.watcher && _enabled && !_startupChecked) {
      _startupChecked = true;
      await _check(automatic: true);
    }
  }

  List<int>? _version(String tag) {
    final match = RegExp(r'^private-network-v(\d+)\.(\d+)\.(\d+)(?:-test(\d+))?$').firstMatch(tag);
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!), int.tryParse(match.group(4) ?? '') ?? 1000000];
  }

  int _compare(String a, String b) {
    final av = _version(a)!;
    final bv = _version(b)!;
    for (var i = 0; i < av.length; i++) {
      if (av[i] != bv[i]) return av[i].compareTo(bv[i]);
    }
    return 0;
  }

  Future<void> _check({bool automatic = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'GBM-Android-UpdateChecker'},
      ),
    );
    try {
      final response = await client.get<String>(
        'https://raw.githubusercontent.com/SuZiYan611/hiddify-app/private-network/updates/android.json',
      );
      final releases =
          [if (response.data != null) jsonDecode(response.data!.replaceFirst('\uFEFF', ''))]
              .whereType<Map<String, dynamic>>()
              .where(
                (r) =>
                    r['draft'] != true &&
                    _version(r['tag_name'] as String? ?? '') != null &&
                    (_currentTag.contains('-test') || r['prerelease'] != true),
              )
              .toList()
            ..sort((a, b) => _compare(b['tag_name'] as String, a['tag_name'] as String));
      if (releases.isEmpty) throw const FormatException('No GBM releases');
      final latest = releases.first;
      final tag = latest['tag_name'] as String;
      if (!mounted) return;
      if (_compare(tag, _currentTag) <= 0) {
        setState(() => _message = '已是最新版本 · $_currentTag');
        if (!automatic) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已是最新版本')));
        return;
      }
      String? download;
      if (Platform.isAndroid) {
        final abis =
            await const MethodChannel('com.hiddify.app/platform').invokeListMethod<String>('supported_abis') ??
            const <String>[];
        final names = <String>[
          if (abis.contains('arm64-v8a')) 'GBM-Android-arm64-debug.apk',
          if (abis.contains('x86_64')) 'GBM-Android-x86_64-debug.apk',
        ];
        for (final asset in (latest['assets'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>()) {
          if (names.contains(asset['name']) && asset['state'] == 'uploaded')
            download = asset['browser_download_url'] as String?;
        }
      }
      final target = Uri.parse(download ?? latest['html_url'] as String);
      if (target.scheme != 'https' ||
          target.host != 'github.com' ||
          !target.path.startsWith('/SuZiYan611/hiddify-app/releases/')) {
        throw const FormatException('Invalid release URL');
      }
      if (!mounted) return;
      setState(() => _message = '发现新版本：$tag');
      final accept = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发现 GBM 新版本'),
          content: Text('$tag${latest['prerelease'] == true ? '（测试版）' : ''}\n\n${latest['body'] ?? ''}'),
          scrollable: true,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍后')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(download == null ? '打开下载页' : '下载更新'),
            ),
          ],
        ),
      );
      if (accept == true && !await launchUrl(target, mode: LaunchMode.externalApplication))
        throw StateError('Cannot open download');
    } catch (error) {
      final reason = error is DioException
          ? switch (error.response?.statusCode) {
              403 => 'GitHub 暂时拒绝请求或请求过于频繁，请稍后重试',
              429 => 'GitHub 请求过于频繁，请稍后重试',
              _ => switch (error.type) {
                DioExceptionType.connectionTimeout ||
                DioExceptionType.receiveTimeout => '连接 GitHub 超时，请检查网络或连接 VPN 后重试',
                DioExceptionType.badCertificate => 'GitHub 安全证书验证失败，请检查设备时间',
                _ => '无法连接 GitHub，请检查网络或连接 VPN 后重试',
              },
            }
          : '更新信息格式异常，请稍后重试';
      debugPrint(
        'GBM update check: ${error.runtimeType}; ${error is DioException ? "${error.type} HTTP ${error.response?.statusCode} ${error.error}" : error}',
      );
      if (mounted) {
        setState(() => _message = reason);
        if (!automatic) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
      }
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.watcher
      ? const SizedBox.shrink()
      : Column(
          children: [
            SwitchListTile(
              title: const Text('自动检查更新'),
              subtitle: const Text('启动时检查 GBM 新版本'),
              value: _enabled,
              onChanged: (value) async {
                await (await SharedPreferences.getInstance()).setBool(_preference, value);
                if (mounted) setState(() => _enabled = value);
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: Text(_busy ? '正在检查更新…' : '立即检查更新'),
              subtitle: Text(_message),
              onTap: _busy ? null : () => _check(),
            ),
            const Divider(),
          ],
        );
}
