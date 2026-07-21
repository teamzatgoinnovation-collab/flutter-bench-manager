import 'package:flutter_test/flutter_test.dart';

import 'package:bench_manager/app.dart';
import 'package:bench_manager/services/session.dart';

void main() {
  testWidgets('shows login when unauthenticated', (tester) async {
    final session = BenchSession();
    await tester.pumpWidget(BenchManagerApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Bench Manager'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
