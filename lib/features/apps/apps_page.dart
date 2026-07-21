import 'package:flutter/material.dart';

import '../../services/bench_api.dart';
import '../../services/session.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Apps · ${widget.session.site}'),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _apps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.extension_outlined),
                          title: Text(_apps[i]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
