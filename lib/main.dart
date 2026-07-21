import 'package:flutter/material.dart';

import 'app.dart';
import 'services/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = BenchSession();
  await session.hydrate();
  runApp(BenchManagerApp(session: session));
}
