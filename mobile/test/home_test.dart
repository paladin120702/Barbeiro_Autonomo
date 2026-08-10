import 'package:barbearia_app/data/models/caixa.dart';
import 'package:barbearia_app/data/repositories/agendamento_repository.dart';
import 'package:barbearia_app/data/repositories/auth_repository.dart';
import 'package:barbearia_app/data/repositories/caixa_repository.dart';
import 'package:barbearia_app/data/repositories/horario_repository.dart';
import 'package:barbearia_app/data/repositories/servico_repository.dart';
import 'package:barbearia_app/features/agenda/tela_agenda_do_dia.dart';
import 'package:barbearia_app/features/auth/tela_login.dart';
import 'package:barbearia_app/features/caixa/tela_caixa.dart';
import 'package:barbearia_app/features/servicos/tela_servicos.dart';
import 'package:barbearia_app/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'home_test.mocks.dart';

/// [Home] é o shell de navegação pós-login e estava sem teste desde a
/// Task 21. Cobre a troca de abas e o logout (que é o único caminho manual
/// de volta ao login).
@GenerateMocks([
  AuthRepository,
  AgendamentoRepository,
  CaixaRepository,
  ServicoRepository,
  HorarioRepository,
])
void main() {
  late MockAuthRepository auth;
  late MockAgendamentoRepository agendamentos;
  late MockCaixaRepository caixa;
  late MockServicoRepository servicos;
  late MockHorarioRepository horarios;

  setUp(() {
    auth = MockAuthRepository();
    agendamentos = MockAgendamentoRepository();
    caixa = MockCaixaRepository();
    servicos = MockServicoRepository();
    horarios = MockHorarioRepository();

    // Cada aba carrega sozinha no construtor do seu ViewModel.
    when(agendamentos.buscarAgendaDoDia(any)).thenAnswer((_) async => []);
    when(caixa.consultarDia(any)).thenAnswer(
      (_) async => const Caixa(total: 0, quantidade: 0, porFormaPagamento: {}),
    );
    when(servicos.listar()).thenAnswer((_) async => []);
    when(horarios.listarHorarios()).thenAnswer((_) async => []);
    when(horarios.listarExcecoes()).thenAnswer((_) async => []);
    when(auth.logout()).thenAnswer((_) async {});
  });

  // Replica a configuração de `App`: os delegates de localização são o que
  // carrega os símbolos de data de pt_BR usados pelas telas.
  Widget montar() => MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: auth),
      Provider<AgendamentoRepository>.value(value: agendamentos),
      Provider<CaixaRepository>.value(value: caixa),
      Provider<ServicoRepository>.value(value: servicos),
      Provider<HorarioRepository>.value(value: horarios),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('pt', 'BR')],
      home: Home(),
    ),
  );

  testWidgets('abre na aba Agenda', (tester) async {
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(find.byType(TelaAgendaDoDia), findsOneWidget);
    expect(find.byType(TelaCaixa), findsNothing);
    verify(agendamentos.buscarAgendaDoDia(any)).called(1);
  });

  testWidgets('tocar numa aba troca a tela exibida', (tester) async {
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Caixa'));
    await tester.pumpAndSettle();

    expect(find.byType(TelaCaixa), findsOneWidget);
    expect(find.byType(TelaAgendaDoDia), findsNothing);

    await tester.tap(find.text('Serviços'));
    await tester.pumpAndSettle();

    expect(find.byType(TelaServicos), findsOneWidget);
    expect(find.byType(TelaCaixa), findsNothing);
  });

  testWidgets('trocar de aba e voltar descarta e recria a tela, refazendo a '
      'requisição — comportamento ATUAL (`body: _abas[_abaAtual]`), não o '
      'desejado; está no backlog trocar por IndexedStack', (tester) async {
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Caixa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();

    verify(agendamentos.buscarAgendaDoDia(any)).called(2);
  });

  testWidgets('logout limpa a sessão e volta pro login, sem deixar a Home '
      'na pilha', (tester) async {
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    verify(auth.logout()).called(1);
    expect(find.byType(TelaLogin), findsOneWidget);

    // `expect(find.byType(Home), findsNothing)` NÃO serviria aqui: a rota
    // nova é opaca, então o Navigator tira a Home da árvore mesmo com um
    // `push` comum — a asserção passaria com ou sem `pushReplacement`
    // (verificado por mutação). O que discrimina é não sobrar rota pra
    // voltar: sem isso, o botão de voltar do Android devolveria o barbeiro
    // deslogado pra dentro do app.
    final contexto = tester.element(find.byType(TelaLogin));
    expect(Navigator.of(contexto).canPop(), isFalse);
  });
}
