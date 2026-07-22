import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';
import '../../widgets/m3_bits.dart';

class SitesPage extends StatefulWidget {
  const SitesPage({super.key, required this.session});

  final BenchSession session;

  @override
  State<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends State<SitesPage> {
  bool _loading = true;
  String? _error;
  List<String> _sites = [];
  EnvHealth? _envHealth;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = widget.session.api;
      final sites = await api.fetchSites(widget.session.env);
      EnvHealth? health;
      try {
        final all = await api.fetchEnvHealth();
        health = all
            .where((h) => h.env == widget.session.env)
            .firstOrNull;
      } catch (_) {
        health = null;
      }
      setState(() {
        _sites = sites;
        _envHealth = health;
      });
    } catch (err) {
      setState(() {
        _error = err is BenchApiException ? err.message : err.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(String site) async {
    await widget.session.setPrefs(env: widget.session.env, site: site);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Site: $site')));
    }
  }

  (String, StatusTone, IconData) _envTone() {
    final h = _envHealth;
    if (h?.running == true) {
      return ('Env healthy', StatusTone.success, Icons.favorite_outline);
    }
    if (h == null) {
      return ('Env unknown', StatusTone.neutral, Icons.help_outline);
    }
    return ('Env down', StatusTone.error, Icons.heart_broken_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final envSt = _envTone();

    return Scaffold(
      appBar: AppBar(
        title: Text('Sites · ${widget.session.env}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: scheme.error, size: 36),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _sites.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyHint(
                          message: 'No sites found for this environment.',
                          icon: Icons.dns_outlined,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionTitle('Site health'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: envSt.$1,
                                      tone: envSt.$2,
                                      icon: envSt.$3,
                                    ),
                                    StatusChip(
                                      label: widget.session.env == 'cloud'
                                          ? 'Cloud'
                                          : 'Local',
                                      tone: StatusTone.info,
                                      icon: widget.session.env == 'cloud'
                                          ? Icons.cloud_outlined
                                          : Icons.computer_outlined,
                                    ),
                                    StatusChip(
                                      label: '${_sites.length} sites',
                                      tone: StatusTone.neutral,
                                      icon: Icons.list_alt_outlined,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap a site to make it the active target for '
                                  'apps and automatic ops.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SectionTitle('Sites'),
                        const SizedBox(height: 10),
                        ..._sites.map((site) {
                          final selected = site == widget.session.site;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              color: selected
                                  ? scheme.primaryContainer.withValues(
                                      alpha: 0.35,
                                    )
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: selected
                                      ? scheme.primary.withValues(alpha: 0.18)
                                      : scheme.surfaceContainerHighest,
                                  foregroundColor: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  child: Icon(
                                    selected
                                        ? Icons.dns
                                        : Icons.dns_outlined,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  site,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  selected
                                      ? 'Active target'
                                      : 'Available on ${widget.session.env}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: selected
                                    ? StatusChip(
                                        label: 'Active',
                                        tone: StatusTone.success,
                                        icon: Icons.check_circle_outline,
                                      )
                                    : Icon(
                                        Icons.chevron_right,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                selected: selected,
                                onTap: () => _select(site),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
            ),
    );
  }
}
