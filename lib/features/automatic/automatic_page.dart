import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';

class AutomaticPage extends StatefulWidget {
  const AutomaticPage({super.key, required this.session});

  final BenchSession session;

  @override
  State<AutomaticPage> createState() => _AutomaticPageState();
}

class _AutomaticPageState extends State<AutomaticPage> {
  bool _busy = false;
  String? _log;
  String? _error;
  List<String> _apps = [];
  String? _buildPkg;

  static const _actions = <(String, String)>[
    ('list-apps', 'List apps'),
    ('migrate', 'Migrate'),
    ('clear-cache', 'Clear cache'),
    ('clear-website-cache', 'Clear website cache'),
    ('build', 'Build --app'),
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await widget.session.api.fetchApps(
        widget.session.env,
        widget.session.site,
      );
      setState(() {
        _apps = apps;
        _buildPkg ??= apps.isNotEmpty ? apps.first : null;
      });
    } catch (_) {}
  }

  Future<void> _run(String action) async {
    setState(() {
      _busy = true;
      _error = null;
      _log = null;
    });
    try {
      final out = await widget.session.api.runAutomatic(
        action: action,
        env: widget.session.env,
        site: widget.session.site,
        packageName: action == 'build' ? _buildPkg : null,
      );
      if (out['async'] == true && out['jobId'] is String) {
        await _pollJob(out['jobId'] as String);
      } else {
        final result = (out['result'] as Map?)?.cast<String, dynamic>();
        final apps = (out['apps'] as List?)?.map((e) => '$e').join(', ');
        setState(() {
          _log = [
            if (result?['command'] != null) '\$ ${result!['command']}',
            if (result?['stdout'] != null) '${result!['stdout']}',
            if (result?['stderr'] != null) '${result!['stderr']}',
            if (apps != null) 'apps: $apps',
          ].where((e) => e.trim().isNotEmpty).join('\n');
        });
      }
    } catch (err) {
      setState(() {
        _error = err is BenchApiException ? err.message : err.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollJob(String id) async {
    for (var i = 0; i < 120; i++) {
      final data = await widget.session.api.fetchJob(id);
      final job = (data['job'] as Map?)?.cast<String, dynamic>() ?? {};
      final log = ((job['log'] as List?) ?? []).map((e) => '$e').join('\n');
      final status = job['status'] as String? ?? '';
      setState(() => _log = log);
      if (status == 'done' || status == 'error' || status == 'failed') {
        if (job['error'] != null) {
          setState(() => _error = '${job['error']}');
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    setState(() => _error = 'Timed out waiting for job $id');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Automatic · ${widget.session.site}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Safe refresh ops on ${widget.session.env}. Requires Bench Manager '
            'running on this machine (or reachable URL).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_apps.isNotEmpty) ...[
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Build package'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _buildPkg != null && _apps.contains(_buildPkg)
                      ? _buildPkg
                      : _apps.first,
                  items: _apps
                      .map(
                        (a) => DropdownMenuItem(value: a, child: Text(a)),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _buildPkg = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions
                .map(
                  (a) => FilledButton.tonal(
                    onPressed: _busy ? null : () => _run(a.$1),
                    child: Text(a.$2),
                  ),
                )
                .toList(),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_log != null) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF111827),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _log!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
