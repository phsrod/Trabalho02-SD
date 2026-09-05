import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Exibe a tela inicial do aplicativo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FotoViaBotaoApp());

    expect(find.text('Foto via Botão'), findsOneWidget);
    expect(find.text('Tirar e Analisar'), findsOneWidget);
  });
}