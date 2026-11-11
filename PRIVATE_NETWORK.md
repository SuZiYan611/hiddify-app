# 私人网络 Android 客户端

基于 [Hiddify](https://github.com/hiddify/hiddify-app) 改编，修改日期 2026-11-11。保留上游许可、署名与版权信息。界面采用现有 VPN 网页的黑白灰配色、地球与城市连线、白色卡片、黑色圆角按钮。

## 实现范围

- 登录、注册、密码确认，调用已有 `/api/login`、`/api/register`、`/api/me`、`/api/logout`。
- 登录后将账户订阅导入原生 Hiddify 配置仓库并激活，使用原引擎连接。
- 连接首页、节点选择、真实延迟、账户页、许可页；原网络设置和诊断仍可使用。
- 区分已连接、连接中、检测中、无可用节点、断开中及连接失败，不提供模拟流量或模拟延迟。
- 单独包名 `com.suziyan.privatenetwork`，名称暂用“私人网络”，自有黑白地球图标。
- 不弹出上游 Hiddify APK 更新，不接受外部 App 的订阅导入链接，避免替换本客户端或错误导入。

## 公开源码与私有后台

客户端公开并不代表服务器、用户数据库或账户订阅公开。本仓库不得加入：真实订阅链接、用户 UUID、会话令牌、服务器密钥、签名密钥、数据库或 `.env`。

客户端使用 HTTPS；登录会话只保存在内存中，冷启动后重新登录。设备会缓存运行 VPN 必需的订阅和节点配置，不能向有权控制设备的登录用户隐藏这些配置。退出时会停止 VPN、等待真实断开状态、清理配置，再请求后台撤销会话。后台不可达时本机会退出，并明确提示服务器会话尚未撤销。

APK 的后台域名、客户端包名等可以被提取，不能当作秘密或鉴权方式。后台必须独立鉴权；限制哪些人能注册、撤销用户的 Xray UUID 等操作仍由后台实施。现有后台的自助注册接口尚未增加邀请制，本次没有改变注册政策。

## GitHub Actions 构建

在公开 Hiddify fork 中使用 `.github/workflows/private-network-android.yml`。工作流会核对它确实来自 Hiddify 的公开 fork。

1. Repository Variables 可设 `PORTAL_BASE_URL=https://你的后台域名`；不设置时用户可以在登录页输入地址。该地址必须是 HTTPS origin，不带 `/api` 路径。
2. 在 Actions 运行 **Private Network Android**。默认产出仅供内部测试的 debug 签名 APK，下载 artifact 安装。
3. 正式签名时，在 GitHub Actions Secrets 配置 `ANDROID_KEYSTORE_BASE64`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD`、`ANDROID_KEY_ALIAS`，手动运行并选 `signed_release`。
4. 正式构建缺少签名密钥会失败，不会退回 debug 签名。构建后删除 runner 内临时签名文件。
5. 每次分发都保留对应源码提交。工作流把本次 commit 的源码地址写进 App 许可页。

采用 Flutter 3.38.5、Java 17、Android SDK 36、NDK 28.2.13676358；引擎按固定上游源码的 `dependencies.properties` 选择 5.5.5。工作流先执行 `make android-prepare`，运行分析及 `test/private_network` 测试，再打包 APK。

## 后台接入前提

后台 `PORTAL_BASE_URL` 应与 App 配置一致，`/api/me` 返回的 `subscription.subscription_url` 必须是同一 HTTPS origin 下的 `/sub/<token>`。不接受跳转到其他站点，也不把用户会话发往订阅服务器。

现有后端说明仍指出 UUID 未验证同步到 AWS Xray；App 只能如实显示后端的 `prototype_notice`，不能通过换界面解决远端用户未配置的问题。可测试注册、登录和订阅格式，真实联网须在 Xray 同步完成后单独验收。

退出登录撤销的是后台会话，不等同于服务端撤销已发放的订阅令牌或 Xray UUID。要取消用户网络权限，须在服务端实现禁用/撤销。

## 当前验证状态

改版源码和构建工作流已经编写；本次环境缺少 Flutter、Dart、Java 和 Android SDK，未执行 Flutter 分析、Flutter 测试、APK 编译或真机连接测试。构建成功、界面布局、系统 VPN 授权、后台切换、断线恢复及真实联网均需后续验证。

## 许可

查看原始 `LICENSE.md`。保留 Hiddify 署名，公开对应 fork 代码；按原仓库列出的要求使用 GitHub Actions 发布。商业授权另行取得。源码公开时只公开客户端及构建说明，不公开签名和服务器凭据。
