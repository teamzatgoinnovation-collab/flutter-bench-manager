import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';
import '../../widgets/m3_bits.dart';

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
          final msg =
              (settings['sshError'] as String?) ??
              'Complete Cloud setup in Bench Manager Settings first '
                  '(localhost ops host).';
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
          return;
        }
        final site =
            (settings['settings'] as Map?)?['doDefaultSite'] as String? ??
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

  (String, StatusTone, IconData) _localStatus(EnvHealth? local) {
    if (local?.running == true) {
      return ('Running', StatusTone.success, Icons.check_circle_outline);
    }
    return ('Down', StatusTone.error, Icons.cancel_outlined);
  }

  (String, StatusTone, IconData) _cloudStatus(EnvHealth? cloud) {
    if (cloud?.running == true) {
      return ('Running', StatusTone.success, Icons.check_circle_outline);
    }
    if (_sshReady == false) {
      return ('SSH not ready', StatusTone.warning, Icons.key_off_outlined);
    }
    return ('Down', StatusTone.error, Icons.cancel_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final local = _health.where((h) => h.env == 'local').firstOrNull;
    final cloud = _health.where((h) => h.env == 'cloud').firstOrNull;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localSt = _localStatus(local);
    final cloudSt = _cloudStatus(cloud);
    final isCloud = widget.session.env == 'cloud';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bench Manager'),
        actions: [
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Environment'),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(
                          value: 'local',
                          label: Text('Local'),
                          icon: Icon(Icons.computer_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: 'cloud',
                          label: Text(_cloudLabel),
                          icon: const Icon(Icons.cloud_outlined, size: 18),
                        ),
                      ],
                      selected: {widget.session.env},
                      onSelectionChanged: (s) => _switchEnv(s.first),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.session.site,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: isCloud ? _cloudLabel : 'Local',
                          tone: StatusTone.info,
                          icon: isCloud
                              ? Icons.cloud_outlined
                              : Icons.computer_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: _loading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_loading ? 'Refreshing…' : 'Refresh status'),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
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
            if (_loading && _health.isEmpty) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              const SizedBox(height: 20),
              const SectionTitle('Health'),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Active env',
                value: isCloud ? _cloudLabel : 'Local',
                subtitle: widget.session.site,
                status: StatusChip(
                  label: 'Selected',
                  tone: StatusTone.info,
                  icon: Icons.radio_button_checked,
                ),
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Local backend',
                value: local?.running == true ? 'Running' : 'Down',
                subtitle: local?.container,
                status: StatusChip(
                  label: localSt.$1,
                  tone: localSt.$2,
                  icon: localSt.$3,
                ),
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: _cloudLabel,
                value: cloud?.running == true
                    ? 'Running'
                    : (_sshReady == false ? 'SSH not ready' : 'Down'),
                subtitle: cloud?.sshHostRedacted ?? cloud?.container,
                status: StatusChip(
                  label: cloudSt.$1,
                  tone: cloudSt.$2,
                  icon: cloudSt.$3,
                ),
              ),
              const SizedBox(height: 10),
              _StatCard(
                title: 'Installed apps',
                value: '${_apps.length}',
                subtitle: widget.session.site,
                status: StatusChip(
                  label: _apps.isEmpty ? 'None' : '${_apps.length} apps',
                  tone: _apps.isEmpty ? StatusTone.neutral : StatusTone.success,
                  icon: Icons.extension_outlined,
                ),
              ),
              if (_apps.isNotEmpty) ...[
                const SizedBox(height: 20),
                const SectionTitle('Apps on site'),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _apps
                          .map(
                            (a) => Chip(
                              avatar: Icon(
                                Icons.extension_outlined,
                                size: 16,
                                color: scheme.primary,
                              ),
                              label: Text(a),
                              visualDensity: VisualDensity.compact,
                              side: BorderSide(
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
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
    this.status,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?status,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
