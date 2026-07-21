import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});

  final BenchSession session;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  List<EnvHealth> _health = [];
  List<String> _apps = [];
  bool? _sshReady;
  String _cloudLabel = 'Cloud';

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.session.api;
      final health = await api.fetchEnvHealth();
      final apps = await api.fetchApps(widget.session.env, widget.session.site);
      final settings = await api.fetchSettings();
      final provider =
          (settings['settings'] as Map?)?['cloudProvider'] as String? ??
              'digitalocean';
      setState(() {
        _health = health;
        _apps = apps;
        _sshReady = settings['sshReady'] == true;
        _cloudLabel = switch (provider) {
          'hetzner' => 'Hetzner',
          'azure' => 'Azure',
          'aws' => 'AWS',
          'digitalocean' => 'DigitalOcean',
          _ => 'Cloud',
        };
      });
    } catch (err) {
      setState(() {
        _error = err is BenchApiException ? err.message : err.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchEnv(String env) async {
    try {
      if (env == 'cloud') {
        final settings = await widget.session.api.fetchSettings();
        if (settings['hosted'] == true || settings['sshReady'] != true) {
          final msg = (settings['sshError'] as String?) ??
              'Complete Cloud setup in Bench Manager Settings first '
                  '(localhost ops host).';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
          return;
        }
        final site = (settings['settings'] as Map?)?['doDefaultSite'] as String? ??
            widget.session.site;
        await widget.session.setPrefs(env: 'cloud', site: site);
      } else {
        await widget.session.setPrefs(env: 'local', site: widget.session.site);
      }
      await _load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err is BenchApiException ? err.message : err.toString(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = _health.where((h) => h.env == 'local').firstOrNull;
    final cloud = _health.where((h) => h.env == 'cloud').firstOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bench Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                const ButtonSegment(value: 'local', label: Text('Local')),
                ButtonSegment(value: 'cloud', label: Text(_cloudLabel)),
              ],
              selected: {widget.session.env},
              onSelectionChanged: (s) => _switchEnv(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              'Site ${widget.session.site}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 16),
              _StatCard(
                title: 'Active env',
                value: widget.session.env == 'cloud' ? _cloudLabel : 'Local',
                subtitle: widget.session.site,
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Local backend',
                value: local?.running == true ? 'Running' : 'Down',
                subtitle: local?.container,
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: _cloudLabel,
                value: cloud?.running == true
                    ? 'Running'
                    : (_sshReady == false ? 'SSH not ready' : 'Down'),
                subtitle: cloud?.sshHostRedacted ?? cloud?.container,
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Installed apps',
                value: '${_apps.length}',
                subtitle: widget.session.site,
              ),
              if (_apps.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Apps', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _apps
                      .map(
                        (a) => Chip(
                          label: Text(a),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.headlineSmall),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
