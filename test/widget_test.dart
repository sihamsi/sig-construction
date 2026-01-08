import 'package:flutter_test/flutter_test.dart';
import 'package:sig_construction/main.dart';

void main() {
  testWidgets('Login UI shows correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SigConstructionApp());

    expect(find.text('SIG Construction'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('Compte test'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });
}
