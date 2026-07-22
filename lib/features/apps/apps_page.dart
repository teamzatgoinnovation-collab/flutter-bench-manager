import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';
import '../../widgets/m3_bits.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key, required this.session});

  final BenchSession session;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  bool _loading = true;
  String? _error;
  List<String> _apps = [];

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
      final apps = await widget.session.api.fetchApps(
        widget.session.env,
        widget.session.site,
      );
      setState(() => _apps = apps);
    } catch (err) {
      setState(() {
        _error = err is BenchApiException ? err.message : err.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Apps · ${widget.session.site}'),
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
              child: _apps.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyHint(
                          message: 'No installed apps on this site.',
                          icon: Icons.extension_off_outlined,
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
                                const SectionTitle('Installed apps'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: '${_apps.length} packages',
                                      tone: StatusTone.success,
                                      icon: Icons.extension_outlined,
                                    ),
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
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Packages reported by bench for the active '
                                  'environment and site.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SectionTitle('Packages'),
                        const SizedBox(height: 10),
                        ..._apps.asMap().entries.map((entry) {
                          final i = entry.key;
                          final name = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  foregroundColor: scheme.primary,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Installed',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: StatusChip(
                                  label: 'OK',
                                  tone: StatusTone.success,
                                  icon: Icons.check,
                                ),
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
