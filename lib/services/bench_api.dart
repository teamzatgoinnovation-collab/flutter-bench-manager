import 'dart:convert';

import 'package:http/http.dart' as http;

class BenchApiException implements Exception {
  BenchApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class SessionInfo {
  SessionInfo({
    required this.authenticated,
    required this.env,
    required this.site,
  });
  final bool authenticated;
  final String env;
  final String site;
}

class EnvHealth {
  EnvHealth({
    required this.env,
    required this.container,
    required this.running,
    this.sshHostRedacted,
    this.sshError,
  });
  final String env;
  final String container;
  final bool running;
  final String? sshHostRedacted;
  final String? sshError;
}

class BenchApi {
  BenchApi({this.baseUrl = 'http://127.0.0.1:3008', this.token});

  String baseUrl;
  String? token;

  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      h['Cookie'] = 'bm_auth=$token';
    }
    return h;
  }

  Uri _u(String path, [Map<String, String>? query]) {
    final root = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$root$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _json(
    Future<http.Response> future,
  ) async {
    final res = await future;
    Map<String, dynamic> body = {};
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    if (res.statusCode >= 400) {
      throw BenchApiException(
        (body['error'] as String?) ?? res.reasonPhrase ?? 'Request failed',
        statusCode: res.statusCode,
      );
    }
    return body;
  }

  Future<void> login(String token) async {
    await _json(
      http.post(
        _u('/api/auth/login'),
        headers: _headers,
        body: jsonEncode({'token': token}),
      ),
    );
    this.token = token;
  }

  Future<void> logout() async {
    await _json(http.post(_u('/api/auth/logout'), headers: _headers));
    token = null;
  }

  Future<SessionInfo> session() async {
    final data = await _json(http.get(_u('/api/auth/session'), headers: _headers));
    final prefs = (data['prefs'] as Map?)?.cast<String, dynamic>() ?? {};
    return SessionInfo(
      authenticated: data['authenticated'] == true,
      env: (prefs['env'] as String?) ?? 'local',
      site: (prefs['site'] as String?) ?? 'accounting.zatgoinnovation.com',
    );
  }

  Future<void> savePrefs({required String env, required String site}) async {
    await _json(
      http.post(
        _u('/api/sites'),
        headers: _headers,
        body: jsonEncode({'env': env, 'site': site}),
      ),
    );
  }

  Future<List<EnvHealth>> fetchEnvHealth() async {
    final data = await _json(http.get(_u('/api/env'), headers: _headers));
    final health = (data['health'] as List?) ?? [];
    return health.map((raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return EnvHealth(
        env: (m['env'] as String?) ?? '',
        container: (m['container'] as String?) ?? '',
        running: m['running'] == true,
        sshHostRedacted: m['sshHostRedacted'] as String?,
        sshError: m['sshError'] as String?,
      );
    }).toList();
  }

  Future<List<String>> fetchSites(String env) async {
    final data = await _json(
      http.get(_u('/api/sites', {'env': env}), headers: _headers),
    );
    return ((data['sites'] as List?) ?? []).map((e) => '$e').toList();
  }

  Future<List<String>> fetchApps(String env, String site) async {
    final data = await _json(
      http.get(
        _u('/api/apps', {'env': env, 'site': site}),
        headers: _headers,
      ),
    );
    return ((data['apps'] as List?) ?? []).map((e) => '$e').toList();
  }

  Future<Map<String, dynamic>> fetchSettings() async {
    return _json(http.get(_u('/api/settings'), headers: _headers));
  }

  Future<Map<String, dynamic>> runAutomatic({
    required String action,
    required String env,
    required String site,
    String? packageName,
  }) async {
    return _json(
      http.post(
        _u('/api/bench/automatic'),
        headers: _headers,
        body: jsonEncode({
          'action': action,
          'env': env,
          'site': site,
          if (packageName != null && packageName.isNotEmpty)
            'package': packageName,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> fetchJob(String id) async {
    return _json(
      http.get(_u('/api/jobs/${Uri.encodeComponent(id)}'), headers: _headers),
    );
  }
}
