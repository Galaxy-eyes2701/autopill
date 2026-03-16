import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  const bullseye = FontAwesomeIcons.bullseye;

  testWidgets('find.byIcon', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: FaIcon(bullseye)),
    );
    expect(find.byIcon(bullseye), findsOneWidget);
  });

  testWidgets('find.widgetWithIcon', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: FaIcon(bullseye)),
    );
    expect(find.widgetWithIcon(Directionality, bullseye), findsOneWidget);
  });
}
