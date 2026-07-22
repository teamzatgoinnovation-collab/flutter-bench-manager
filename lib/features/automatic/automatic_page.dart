import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';
import '../../widgets/m3_bits.dart';

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
  String? _lastAction;

  static const _primaryActions = <(String, String, IconData)>[
    ('migrate', 'Migrate', Icons.sync_alt),
    ('clear-cache', 'Clear cache', Icons.cleaning_services_outlined),
  ];

  static const _secondaryActions = <(String, String, IconData)>[
    ('list-apps', 'List apps', Icons.list_alt_outlined),
    ('clear-website-cache', 'Clear website cache', Icons.language_outlined),
    ('build', 'Build --app', Icons.build_outlined),
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
      _lastAction = action;
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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Automatic · ${widget.session.site}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Target'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusChip(
                        label: widget.session.env,
                        tone: StatusTone.info,
                        icon: Icons.dns_outlined,
                      ),
                      StatusChip(
                        label: widget.session.site,
                        tone: StatusTone.neutral,
                        icon: Icons.language_outlined,
                      ),
                      if (_busy)
                        StatusChip(
                          label: _lastAction ?? 'Running',
                          tone: StatusTone.warning,
                          icon: Icons.hourglass_top,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Safe refresh ops on ${widget.session.env}. Requires Bench '
                    'Manager running on this machine (or reachable URL).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_apps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Build package'),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Package for Build --app',
                        prefixIcon: Icon(Icons.extension_outlined),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _buildPkg != null && _apps.contains(_buildPkg)
                              ? _buildPkg
                              : _apps.first,
                          items: _apps
                              .map(
                                (a) =>
                                    DropdownMenuItem(value: a, child: Text(a)),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _buildPkg = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const SectionTitle('Primary actions'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _primaryActions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(_primaryActions[i].$1),
                      icon: Icon(_primaryActions[i].$3, size: 18),
                      label: Text(_primaryActions[i].$2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('More ops'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _secondaryActions
                    .map(
                      (a) => OutlinedButton.icon(
                        onPressed: _busy ? null : () => _run(a.$1),
                        icon: Icon(a.$3, size: 18),
                        label: Text(a.$2),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Running ${_lastAction ?? 'job'}…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_log != null) ...[
            const SizedBox(height: 16),
            const SectionTitle('Output'),
            const SizedBox(height: 10),
            Card(
              color: isDark ? const Color(0xFF0B1220) : const Color(0xFF111827),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  _log!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFFE5E7EB),
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
