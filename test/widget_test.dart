import 'package:flutter_test/flutter_test.dart';
import 'package:swipe/main.dart';

void main() {
  testWidgets('App should start correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SwipeCleanerApp());
    expect(find.text('Swipe Cleaner'), findsOneWidget);
  });
}
