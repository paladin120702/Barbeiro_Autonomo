import 'dart:async';

import 'package:barbearia_app/app.dart';
import 'package:barbearia_app/data/repositories/agendamento_repository.dart';
import 'package:barbearia_app/data/repositories/auth_repository.dart';
import 'package:barbearia_app/features/auth/tela_login.dart';
import 'package:barbearia_app/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'app_test.mocks.dart';

/// [App] é o único ponto do app que decide entre sessão salva e login, e
/// estava sem teste desde a Task 21. Estes testes cobrem os três estados do
/// `FutureBuilder` de `temSessao()` — inclusive o de falha, que cai no
/// mesmo ramo do `?? false`.
@GenerateMocks([AuthRepository, AgendamentoRepository])
void main() {
  late MockAuthRepository auth;
  late MockAgendamentoRepository agendamentos;

  setUp(() {
    auth = MockAuthRepository();
    agendamentos = MockAgendamentoRepository();
    // Home monta a aba Agenda, que carrega sozinha no construtor do VM.
    when(
      agendamentos.buscarAgendaDoDia(any),
    ).thenAnswer((_) async => []);
  });

  Widget montar() => MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: auth),
      Provider<AgendamentoRepository>.value(value: agendamentos),
    ],
    child: App(navigatorKey: GlobalKey<NavigatorState>()),
  );

  testWidgets('enquanto temSessao() não resolve, mostra indicador de '
      'carregamento — nem login nem Home', (tester) async {
    final pendente = Completer<bool>();
    when(auth.temSessao()).thenAnswer((_) => pendente.future);

    await tester.pumpWidget(montar());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TelaLogin), findsNothing);
    expect(find.byType(Home), findsNothing);

    // Resolve pra não deixar o Completer pendente no fim do teste.
    pendente.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('com sessão salva, entra direto na Home', (tester) async {
    when(auth.temSessao()).thenAnswer((_) async => true);

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byType(Home), findsOneWidget);
    expect(find.byType(TelaLogin), findsNothing);
  });

  testWidgets('sem sessão salva, abre a tela de login', (tester) async {
    when(auth.temSessao()).thenAnswer((_) async => false);

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byType(TelaLogin), findsOneWidget);
    expect(find.byType(Home), findsNothing);
  });

  testWidgets('se temSessao() falhar (ex.: storage seguro indisponível), cai '
      'no login em vez de travar no indicador — é o `?? false` do builder',
      (tester) async {
    when(auth.temSessao()).thenAnswer((_) async => throw Exception('storage'));

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byType(TelaLogin), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('o locale pt-BR está configurado: o app declara pt_BR como '
      'único locale suportado (sem isso os pickers do framework voltam pro '
      'inglês e o date picker por teclado vira mm/dd/yyyy)', (tester) async {
    when(auth.temSessao()).thenAnswer((_) async => false);

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.supportedLocales, [const Locale('pt', 'BR')]);
    expect(Localizations.localeOf(tester.element(find.byType(TelaLogin))),
        const Locale('pt', 'BR'));
  });
}
