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
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
      uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const PortalFailure('请输入后台的 HTTPS 地址，例如 https://vpn.example.com');
  }
  return uri.replace(path: '');
}

Uri validateSubscription(Uri origin, String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.origin != origin.origin ||
      uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
      !RegExp(r'^/sub/[a-zA-Z0-9_-]+$').hasMatch(uri.path)) {
    throw const PortalFailure('后台返回的订阅地址无效，请检查服务器 PORTAL_BASE_URL 配置。');
  }
  return uri;
}

class PortalAccount {
  const PortalAccount({required this.email, required this.subscription, required this.notice, this.nodeNames = const []});
  final String email;
  final Uri subscription;
  final String? notice;
  final List<String> nodeNames;

  factory PortalAccount.fromJson(Map<String, dynamic> json, Uri origin) {
    final subscription = json['subscription'];
    final email = json['email'];
    if (email is! String || email.isEmpty || subscription is! Map ||
        subscription['subscription_url'] is! String) {
      throw const PortalFailure('后台账户数据格式不正确。');
    }
    final notice = json['prototype_notice'];
    final rawNodes = json['nodes'];
    if (rawNodes != null && (rawNodes is! List || rawNodes.any((node) =>
        node is! Map || node['name'] is! String || (node['name'] as String).trim().isEmpty))) {
      throw const PortalFailure('后台节点数据格式不正确。');
    }
    return PortalAccount(
      email: email,
      subscription: validateSubscription(origin, subscription['subscription_url'] as String),
      notice: notice is String && notice.trim().isNotEmpty ? notice : null,
      nodeNames: List.unmodifiable((rawNodes as List? ?? []).map((node) => ((node as Map)['name'] as String).trim())),
    );
  }

  @override
  String toString() => 'PortalAccount([REDACTED])';
}

class PortalApi {
  PortalApi(String origin, {HttpClientAdapter? adapter}) : origin = validatePortalOrigin(origin) {
    _dio = Dio(BaseOptions(
      baseUrl: this.origin.origin,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    ));
    if (adapter != null) _dio.httpClientAdapter = adapter;
    // No logging interceptor. Session tokens are sent only to this HTTPS origin.
  }

  final Uri origin;
  late final Dio _dio;

  Future<Map<String, dynamic>> _request(String path, {String? token, Map<String, String>? body}) async {
    try {
      final response = await _dio.request<dynamic>(path,
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
      if (status == 400 && path == '/api/register') {
        throw const PortalFailure('注册未完成：请确认邮箱已获邀请，且账户信息符合要求。');
      }
      if (status == 401 || status == 403) {
        throw PortalFailure(path == '/api/login' ? '邮箱或密码错误。' : '登录已失效，请重新登录。',
          unauthorized: path != '/api/login');
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
    await _request('/api/register', body: {
      'email': email.trim(), 'password': password, 'confirm_password': confirmation,
    });
  }

  Future<String> login(String email, String password) async {
    final data = await _request('/api/login', body: {'email': email.trim(), 'password': password});
    final token = data['session_token'];
    if (token is! String || token.isEmpty) throw const PortalFailure('后台未返回有效会话。');
    return token;
  }

  Future<PortalAccount> me(String token) async => PortalAccount.fromJson(await _request('/api/me', token: token), origin);

  Future<void> logout(String token) async {
    await _request('/api/logout', token: token, body: {});
  }

  void close() => _dio.close(force: true);
}
