import 'package:flutter/material.dart';

import 'features/login/login_page.dart';
import 'features/shell/app_shell.dart';
import 'services/session.dart';
import 'theme.dart';

class BenchManagerApp extends StatefulWidget {
  const BenchManagerApp({super.key, required this.session});

  final BenchSession session;

  @override
  State<BenchManagerApp> createState() => _BenchManagerAppState();
}

class _BenchManagerAppState extends State<BenchManagerApp> {
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZatGo Bench Manager',
      debugShowCheckedModeBanner: false,
      theme: buildBenchTheme(),
      home: widget.session.authenticated
          ? AppShell(session: widget.session)
          : LoginPage(session: widget.session),
    );
  }
}
