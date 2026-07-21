import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';

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
      final sites = await widget.session.api.fetchSites(widget.session.env);
      setState(() => _sites = sites);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Site: $site')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sites · ${widget.session.env}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sites.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final site = _sites[i];
                      final selected = site == widget.session.site;
                      return Card(
                        child: ListTile(
                          title: Text(site),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          selected: selected,
                          onTap: () => _select(site),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
