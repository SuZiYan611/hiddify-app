import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/app_based_routing/data/selected_data_provider.dart';
import 'package:hiddify/features/app_based_routing/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/app_based_routing/overview/app_based_routing_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 内置常用中国主流应用包名白名单，离线/首次启动即刻可用
const Set<String> defaultChinaAppPackages = {
  // 社交与通讯
  'com.tencent.mm', // 微信
  'com.tencent.mobileqq', // QQ
  'com.tencent.tim', // TIM
  'com.tencent.qqlite', // QQ极速版
  'com.alibaba.android.rimet', // 钉钉
  'com.ss.android.lark', // 飞书
  'com.tencent.wework', // 企业微信
  'com.sina.weibo', // 微博
  'com.sina.weibog3', // 微博轻享版
  'com.zhihu.android', // 知乎
  'com.xingin.xhs', // 小红书
  'com.douban.frodo', // 豆瓣
  'com.baidu.tieba', // 贴吧
  'cn.soulapp.android', // Soul
  'com.hupu.games', // 虎扑
  // 购物与支付
  'com.eg.android.AlipayGphone', // 支付宝
  'com.alipay.android.app', // 支付宝辅助
  'com.taobao.taobao', // 淘宝
  'com.taobao.litetao', // 淘特
  'com.jingdong.app.mall', // 京东
  'com.jd.jdlite', // 京东极速版
  'com.xunmeng.pinduoduo', // 拼多多
  'com.sankuai.meituan', // 美团
  'com.sankuai.meituan.takeoutnew', // 美团外卖
  'me.ele', // 饿了么
  'com.dianping.v1', // 大众点评
  'com.suning.mobile.ebuy', // 苏宁易购
  'com.achievo.vipshop', // 唯品会
  'com.taobao.idlefish', // 闲鱼
  'com.shizhuang.duapp', // 得物
  'com.unionpay', // 云闪付
  // 影音与娱乐
  'com.ss.android.ugc.aweme', // 抖音
  'com.ss.android.ugc.aweme.lite', // 抖音极速版
  'com.smile.gifmaker', // 快手
  'com.kuaishou.nebula', // 快手极速版
  'tv.danmaku.bili', // 哔哩哔哩
  'com.bilibili.app.in', // Bilibili 国际版
  'com.tencent.qqlive', // 腾讯视频
  'com.qiyi.video', // 爱奇艺
  'com.youku.phone', // 优酷
  'com.hunantv.imgo.activity', // 芒果TV
  'com.ss.android.article.video', // 西瓜视频
  'target.san', // AcFun
  'com.xunlei.downloadprovider', // 迅雷
  // 音乐与音频
  'com.netease.cloudmusic', // 网易云音乐
  'com.tencent.qqmusic', // QQ音乐
  'com.kugou.android', // 酷狗音乐
  'com.kugou.android.lite', // 酷狗概念版
  'cn.kuwo.player', // 酷我音乐
  'com.ximalaya.ting.android', // 喜马拉雅
  'cmcc.mobilevideo', // 咪咕视频/音乐
  // 出行与地图
  'com.autonavi.minimap', // 高德地图
  'com.baidu.BaiduMap', // 百度地图
  'com.tencent.map', // 腾讯地图
  'com.sdu.didi.psnger', // 滴滴出行
  'com.didipinche.booking', // 滴答出行
  'com.cheezheng.app', // 铁路12306
  'com.MobileTicket', // 掌上12306
  'com.ctrip.view', // 携程
  'com.Qunar', // 去哪儿
  'com.taobao.trip', // 飞猪
  'com.tongcheng.android', // 同程旅行
  // 新闻与阅读
  'com.ss.android.article.news', // 今日头条
  'com.ss.android.article.lite', // 头条极速版
  'com.tencent.news', // 腾讯新闻
  'com.netease.newsreader.activity', // 网易新闻
  'com.sina.news', // 新浪新闻
  'com.tencent.weread', // 微信读书
  'com.dragon.read', // 番茄免费小说
  // 搜索与工具
  'com.baidu.searchbox', // 百度搜索
  'com.baidu.netdisk', // 百度网盘
  'com.quark.browser', // 夸克
  'com.UCMobile', // UC浏览器
  'cn.wps.moffice_eng', // WPS Office
  'com.alicloud.databox', // 阿里云盘
  // 常用银行与金融
  'com.icbc', // 中国工商银行
  'com.chinamworld.main', // 中国建设银行
  'com.abchina.mobile.client', // 中国农业银行
  'com.boc.bocsoft', // 中国银行
  'com.cmbchina.ccd.plAMap', // 招商银行
  'com.bankcomm.Bankcomm', // 交通银行
  'com.yitong.mbank.psbc', // 邮储银行
  'com.ecitic.bank.mobile', // 中信银行
  'com.cmbc.activity', // 民生银行
  'com.pingan.paces.ccms', // 平安口袋银行
  'com.hexin.plat.android', // 同花顺
};

class GbmChinaBypassHelper {
  static const _initializedKey = 'gbm_china_bypass_initialized_v2';

  /// 首次启动或初始化时默认开启中国应用分流并装载白名单
  static Future<void> ensureDefaultEnabled(WidgetRef ref) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider).requireValue;
      final initialized = prefs.getBool(_initializedKey) ?? false;
      if (!initialized) {
        debugPrint('[GBM] Initializing default China App bypass (Mode: exclude, Enabled: true)');
        await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
        await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
        await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
        await ref.read(appBasedRoutingProvider.future);
        await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
        await ref
            .read(appProxyDataSourceProvider)
            .applyAutoSelection(autoList: defaultChinaAppPackages, mode: AppProxyMode.exclude);
        await prefs.setBool(_initializedKey, true);
        // 尝试后台异步同步最新的在线大陆应用名单
        unawaited(syncFromRemote(ref, silent: true));
      }
    } catch (e) {
      debugPrint('[GBM] Error ensuring default China bypass: $e');
    }
  }

  /// 切换分流直连总开关
  static Future<void> toggleEnabled(WidgetRef ref, bool enabled) async {
    await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
    await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
    await ref.read(Preferences.perAppProxyEnabled.notifier).update(enabled);
    await ref.read(appBasedRoutingProvider.future);
    await ref.read(appBasedRoutingProvider.notifier).setEnabled(enabled);
  }

  /// 恢复内置默认大陆白名单
  static Future<int> restoreDefaultList(WidgetRef ref) async {
    await ref
        .read(appProxyDataSourceProvider)
        .applyAutoSelection(autoList: defaultChinaAppPackages, mode: AppProxyMode.exclude);
    await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
    await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
    await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
    await ref.read(appBasedRoutingProvider.future);
    await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
    return defaultChinaAppPackages.length;
  }

  /// 从远程 GitHub 规则库同步最新大陆应用直连名单
  static Future<int> syncFromRemote(WidgetRef ref, {bool silent = false}) async {
    try {
      const base = 'https://raw.githubusercontent.com/mnixry/direct-android-ruleset/rules/@Merged';
      final client = ref.read(httpClientProvider);
      final responses = await Future.wait([
        client.get<String>('$base/APP.mutated.yaml'),
        client.get<String>('$base/GAME.mutated.yaml'),
      ]);
      final yaml = responses.map((r) => r.data ?? '').join('\n');
      final packages = RegExp(
        r'^\s*-\s*PROCESS-NAME,([^,#\s]+)',
        multiLine: true,
      ).allMatches(yaml).map((m) => m.group(1)!.trim()).toSet();

      // 合并内置常用包和远程包
      final merged = {...defaultChinaAppPackages, ...packages};
      await ref.read(appProxyDataSourceProvider).applyAutoSelection(autoList: merged, mode: AppProxyMode.exclude);
      await ref.read(Preferences.perAppProxyMode.notifier).update(AppProxyMode.exclude);
      await ref.read(Preferences.autoAppsSelectionOffByUser.notifier).update(true);
      await ref.read(Preferences.perAppProxyEnabled.notifier).update(true);
      await ref.read(appBasedRoutingProvider.future);
      await ref.read(appBasedRoutingProvider.notifier).setEnabled(true);
      return merged.length;
    } catch (e) {
      if (!silent) rethrow;
      return defaultChinaAppPackages.length;
    }
  }
}
