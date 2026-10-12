import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bench_api.dart';

class BenchSession extends ChangeNotifier {
  BenchSession({BenchApi? api}) : _api = api ?? BenchApi();

  final BenchApi _api;

  bool authenticated = false;
  String env = 'local';
  String site = 'accounting.zatgoinnovation.com';
  String? lastError;

  BenchApi get api => _api;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final base = prefs.getString('bm_base_url') ??
        const String.fromEnvironment(
          'BENCH_MANAGER_URL',
          defaultValue: 'http://127.0.0.1:3008',
        );
    final token = prefs.getString('bm_token');
    env = prefs.getString('bm_env') ?? 'local';
    site = prefs.getString('bm_site') ?? 'accounting.zatgoinnovation.com';
    _api.baseUrl = base;
    _api.token = token;
    if (token != null && token.isNotEmpty) {
      try {
        final session = await _api.session();
        authenticated = session.authenticated;
        env = session.env;
        site = session.site;
      } catch (_) {
        authenticated = false;
      }
    }
    notifyListeners();
  }

  Future<void> login({required String baseUrl, required String token}) async {
    lastError = null;
    _api.baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    await _api.login(token.trim());
    authenticated = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bm_base_url', _api.baseUrl);
    await prefs.setString('bm_token', token.trim());
    try {
      final session = await _api.session();
      env = session.env;
      site = session.site;
      await prefs.setString('bm_env', env);
      await prefs.setString('bm_site', site);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    authenticated = false;
    _api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bm_token');
    notifyListeners();
  }

  Future<void> setPrefs({required String env, required String site}) async {
    await _api.savePrefs(env: env, site: site);
    this.env = env;
    this.site = site;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bm_env', env);
    await prefs.setString('bm_site', site);
    notifyListeners();
  }
}
