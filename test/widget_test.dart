import 'package:flutter_test/flutter_test.dart';
import 'package:diafon_mobil_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DiafonApp());
    expect(find.text('Diafon'), findsOneWidget);
  });
}
