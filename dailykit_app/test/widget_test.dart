import 'package:flutter_test/flutter_test.dart';
import 'package:dailykit_app/main.dart';

void main() {
  testWidgets('DailyKitApp basic widget build test', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyKitApp());
    expect(find.byType(DailyKitApp), findsOneWidget);
  });
}
