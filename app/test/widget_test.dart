import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Exibe a tela inicial do aplicativo', (WidgetTester tester) async {
    await tester.pumpWidget(const FotoViaBotaoApp());

    // Aguarda a inicialização da câmera terminar (ela falha no ambiente de
    // teste, o que é tratado pela tela com uma mensagem de erro).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Título da barra superior.
    expect(find.text('Detecção de Objetos'), findsOneWidget);

    // Botão de alternar câmera presente na prévia.
    expect(find.byTooltip('Alternar câmera'), findsOneWidget);

    // Botão obturador acessível.
    expect(find.bySemanticsLabel('Tirar foto e analisar'), findsOneWidget);

    // Como a câmera não existe no ambiente de teste, a mensagem de erro
    // deve ser exibida no lugar da prévia.
    expect(
      find.text('Não foi possível inicializar a câmera.'),
      findsOneWidget,
    );

    // Status da conexão no rodapé (valores padrão).
    expect(find.text('Servidor: 192.168.0.100:5000'), findsOneWidget);
  });
}