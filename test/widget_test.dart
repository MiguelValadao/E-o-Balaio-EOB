import 'package:flutter_test/flutter_test.dart';
import 'package:eob/main.dart';

void main() {
  testWidgets('starts the live bus map experience', (tester) async {
    await tester.pumpWidget(const EOBApp());

    expect(find.text('E o Balaio?'), findsOneWidget);
    expect(find.byTooltip('Atualizar agora'), findsOneWidget);
  });
}
