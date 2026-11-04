import 'package:flutter_test/flutter_test.dart';
import 'package:mobilibus/main.dart';

void main() {
  testWidgets('starts the live bus map experience', (tester) async {
    await tester.pumpWidget(const MobilibusApp());

    expect(find.text('Mobilibus'), findsOneWidget);
    expect(find.byTooltip('Atualizar agora'), findsOneWidget);
  });
}
