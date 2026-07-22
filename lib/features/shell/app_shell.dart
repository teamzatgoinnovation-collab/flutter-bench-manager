import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../apps/apps_page.dart';
import '../automatic/automatic_page.dart';
import '../dashboard/dashboard_page.dart';
import '../sites/sites_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});

  final BenchSession session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(session: widget.session),
      SitesPage(session: widget.session),
      AppsPage(session: widget.session),
      AutomaticPage(session: widget.session),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        height: 72,
        elevation: 0,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns),
            label: 'Sites',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Auto',
          ),
        ],
      ),
    );
  }
}
