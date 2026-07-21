import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final BenchSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _base;
  late final TextEditingController _token;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(
      text: widget.session.api.baseUrl.isEmpty
          ? 'http://127.0.0.1:3008'
          : widget.session.api.baseUrl,
    );
    _token = TextEditingController();
  }

  @override
  void dispose() {
    _base.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.login(baseUrl: _base.text, token: _token.text);
    } catch (err) {
      setState(() {
        _error = err is BenchApiException ? err.message : err.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'ZATGO',
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 3,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Bench Manager', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Connect to the local ops console (Next.js on this machine). '
                  'Docker and SSH run on the server host — not inside Flutter.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _base,
                  decoration: const InputDecoration(
                    labelText: 'Bench Manager URL',
                    hintText: 'http://127.0.0.1:3008',
                  ),
                  keyboardType: TextInputType.url,
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Token',
                    hintText: 'BENCH_MANAGER_TOKEN',
                  ),
                  obscureText: true,
                  enabled: !_busy,
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Signing in…' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
