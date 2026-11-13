import 'package:dio/dio.dart';

/// Never include response bodies, credentials, URLs or DioException in messages.
class PortalFailure implements Exception {
  const PortalFailure(this.message, {this.unauthorized = false});
  final String message;
  final bool unauthorized;
  @override
  String toString() => message;
}

Uri validatePortalOrigin(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const PortalFailure('请输入后台的 HTTPS 地址，例如 https://vpn.example.com');
  }
  return uri.replace(path: '');
}

Uri validateSubscription(Uri origin, String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.origin != origin.origin ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      !RegExp(r'^/sub/[a-zA-Z0-9_-]+$').hasMatch(uri.path)) {
    throw const PortalFailure('后台返回的订阅地址无效，请检查服务器 PORTAL_BASE_URL 配置。');
  }
  return uri;
}

class PortalAccount {
  const PortalAccount({
    required this.email,
    required this.subscription,
    required this.notice,
    this.nodeNames = const [],
    this.nodes = const [],
    this.remainingDays,
  });
  final String email;
  final Uri subscription;
  final String? notice;
  final List<String> nodeNames;
  final List<PortalNode> nodes;

  /// null means a grandfathered account with no expiry recorded; zero is unpaid/expired.
  final int? remainingDays;

  factory PortalAccount.fromJson(Map<String, dynamic> json, Uri origin) {
    final subscription = json['subscription'];
    final email = json['email'];
    if (email is! String || email.isEmpty || subscription is! Map || subscription['subscription_url'] is! String) {
      throw const PortalFailure('后台账户数据格式不正确。');
    }
    final notice = json['prototype_notice'];
    final rawNodes = json['nodes'];
    final rawDays = json['remaining_days'];
    if (rawNodes != null &&
        (rawNodes is! List ||
            rawNodes.any(
              (node) => node is! Map || node['name'] is! String || (node['name'] as String).trim().isEmpty,
            ))) {
      throw const PortalFailure('后台节点数据格式不正确。');
    }
    if (rawNodes is List &&
        rawNodes.any((raw) {
          final node = raw as Map;
          final longitude = node['longitude'];
          final latitude = node['latitude'];
          return (longitude != null && (longitude is! num || longitude < -180 || longitude > 180)) ||
              (latitude != null && (latitude is! num || latitude < -90 || latitude > 90));
        })) {
      throw const PortalFailure('后台节点坐标数据格式不正确。');
    }
    if (rawDays != null && (rawDays is! int || rawDays < 0)) {
      throw const PortalFailure('后台订阅期限数据格式不正确。');
    }
    final nodes = (rawNodes as List? ?? [])
        .map((raw) {
          final node = raw as Map;
          final name = (node['name'] as String).trim();
          final longitude = node['longitude'] is num
              ? (node['longitude'] as num).toDouble()
              : RegExp(r'malaysia|马来西亚', caseSensitive: false).hasMatch(name)
              ? 101.69
              : null;
          final latitude = node['latitude'] is num
              ? (node['latitude'] as num).toDouble()
              : RegExp(r'malaysia|马来西亚', caseSensitive: false).hasMatch(name)
              ? 3.14
              : null;
          return PortalNode(name: name, longitude: longitude, latitude: latitude);
        })
        .toList(growable: false);
    return PortalAccount(
      email: email,
      subscription: validateSubscription(origin, subscription['subscription_url'] as String),
      notice: notice is String && notice.trim().isNotEmpty ? notice : null,
      nodeNames: List.unmodifiable(nodes.map((node) => node.name)),
      nodes: List.unmodifiable(nodes),
      remainingDays: rawDays as int?,
    );
  }

  @override
  String toString() => 'PortalAccount([REDACTED])';
}

class PortalNode {
  const PortalNode({required this.name, required this.longitude, required this.latitude});
  final String name;
  final double? longitude;
  final double? latitude;
}

class PortalApi {
  PortalApi(String origin, {HttpClientAdapter? adapter}) : origin = validatePortalOrigin(origin) {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.origin.origin,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: false,
        headers: {'Accept': 'application/json'},
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;
    // No logging interceptor. Session tokens are sent only to this HTTPS origin.
  }

  final Uri origin;
  late final Dio _dio;

  Future<Map<String, dynamic>> _request(String path, {String? token, Map<String, String>? body}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: body == null ? 'GET' : 'POST',
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ),
      );
      if (response.data is! Map<String, dynamic>) {
        throw const PortalFailure('后台返回的数据格式不正确。');
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 429) {
        throw const PortalFailure('操作过于频繁，请稍后重试。');
      }
      if (path == '/api/register' && (status == 400 || status == 403)) {
        throw const PortalFailure('此邮箱尚未获邀注册。系统不会发送验证邮件，请联系管理员开通。');
      }
      if (path == '/api/register' && status == 409) {
        throw const PortalFailure('这个邮箱已经注册，请切换到“用户登录”。');
      }
      if (path == '/api/register' && status == 503) {
        throw const PortalFailure('账户配置暂时失败，请稍后重试或联系管理员。');
      }
      if (status == 422 && path == '/api/register') {
        throw const PortalFailure('注册信息未通过检查，请确认邮箱格式、密码长度和两次密码一致。');
      }
      if (status == 401 || status == 403) {
        throw PortalFailure(path == '/api/login' ? '邮箱或密码错误。' : '登录已失效，请重新登录。', unauthorized: path != '/api/login');
      }
      if (status == 400 || status == 409 || status == 422) {
        throw const PortalFailure('请检查邮箱、密码及注册信息；该邮箱也可能已注册。');
      }
      if (status != null && status >= 300 && status < 400) {
        throw const PortalFailure('后台地址发生跳转，请填写最终的 HTTPS 地址。');
      }
      throw const PortalFailure('暂时无法访问账户服务，请检查网络后重试。');
    }
  }

  Future<void> register(String email, String password, String confirmation) async {
    await _request(
      '/api/register',
      body: {'email': email.trim(), 'password': password, 'confirm_password': confirmation},
    );
  }

  Future<String> login(String email, String password) async {
    final data = await _request('/api/login', body: {'email': email.trim(), 'password': password});
    final token = data['session_token'];
    if (token is! String || token.isEmpty) throw const PortalFailure('后台未返回有效会话。');
    return token;
  }

  Future<PortalAccount> me(String token) async =>
      PortalAccount.fromJson(await _request('/api/me', token: token), origin);

  Future<void> logout(String token) async {
    await _request('/api/logout', token: token, body: {});
  }

  void close() => _dio.close(force: true);
}
