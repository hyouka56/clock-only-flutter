import 'package:clock_only/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows only Clock and Alarm navigation', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const ClockApp());
    await tester.pumpAndSettle();

    expect(find.text('Clock'), findsWidgets);
    expect(find.text('Alarm'), findsWidgets);
    expect(find.text('Stopwatch'), findsNothing);
    expect(find.text('Timer'), findsNothing);
  });
}
