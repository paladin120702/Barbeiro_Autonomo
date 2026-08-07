import 'dart:async';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/models/caixa.dart';
import 'package:barbearia_app/data/models/enums.dart';
import 'package:barbearia_app/data/repositories/caixa_repository.dart';
import 'package:barbearia_app/features/caixa/caixa_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'caixa_view_model_test.mocks.dart';

@GenerateMocks([CaixaRepository])
void main() {
  late MockCaixaRepository repository;

  final caixa = Caixa(
    total: 350.0,
    quantidade: 7,
    porFormaPagamento: {
      FormaPagamento.pix: 150.0,
      FormaPagamento.dinheiro: 50.0,
      FormaPagamento.debito: 100.0,
      FormaPagamento.credito: 50.0,
    },
  );

  setUp(() {
    repository = MockCaixaRepository();
  });

  test('inicial: consultarDia é chamado, status sucesso com dados', () async {
    when(repository.consultarDia(any)).thenAnswer((_) async => caixa);

    final viewModel = CaixaViewModel(repository);
    expect(viewModel.status, CaixaStatus.carregando);

    var notificacoes = 0;
    viewModel.addListener(() => notificacoes++);

    await viewModel.carregar();

    expect(viewModel.status, CaixaStatus.sucesso);
    expect(viewModel.caixa, caixa);
    expect(notificacoes, greaterThanOrEqualTo(1));
    verify(repository.consultarDia(any)).called(greaterThanOrEqualTo(1));
    verifyNever(repository.consultarMes(any));
  });

  test('mudarPeriodo(mes) chama consultarMes com a referência atual', () async {
    when(repository.consultarDia(any)).thenAnswer((_) async => caixa);
    when(repository.consultarMes(any)).thenAnswer((_) async => caixa);

    final viewModel = CaixaViewModel(repository);
    await untilCalled(repository.consultarDia(any));

    await viewModel.mudarPeriodo(PeriodoCaixa.mes);

    expect(viewModel.periodo, PeriodoCaixa.mes);
    expect(viewModel.status, CaixaStatus.sucesso);
    verify(repository.consultarMes(viewModel.referencia)).called(1);
  });

  test(
    'carregar com ApiException: status erro e mensagemErro exposta',
    () async {
      when(repository.consultarDia(any)).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Falha ao carregar'),
      );

      final viewModel = CaixaViewModel(repository);

      var notificacoes = 0;
      viewModel.addListener(() => notificacoes++);

      await viewModel.carregar();

      expect(viewModel.status, CaixaStatus.erro);
      expect(viewModel.mensagemErro, 'Falha ao carregar');
      expect(notificacoes, greaterThanOrEqualTo(1));
    },
  );

  test('mudarReferencia troca a referência e recarrega', () async {
    when(repository.consultarDia(any)).thenAnswer((_) async => caixa);

    final viewModel = CaixaViewModel(repository);
    await untilCalled(repository.consultarDia(any));

    final novaData = DateTime(2026, 8, 1);
    await viewModel.mudarReferencia(novaData);

    expect(viewModel.referencia, novaData);
    verify(repository.consultarDia(novaData)).called(1);
  });

  test('guard de sequenciamento: resposta de uma chamada antiga de carregar() '
      'que chega depois de uma mais nova não sobrescreve o estado (ex.: '
      'trocar rápido entre dia e mês)', () async {
    // Cada chamada a consultarDia recebe seu próprio Completer, na ordem
    // em que a chamada foi disparada — permite resolver as respostas fora
    // de ordem para simular a corrida.
    final respostas = <Completer<Caixa>>[];
    when(repository.consultarDia(any)).thenAnswer((_) {
      final completer = Completer<Caixa>();
      respostas.add(completer);
      return completer.future;
    });

    // Geração 1: disparada pelo construtor.
    final viewModel = CaixaViewModel(repository);
    // Geração 2 (antiga) e geração 3 (nova).
    final chamadaAntiga = viewModel.carregar();
    final chamadaNova = viewModel.carregar();
    expect(respostas, hasLength(3));

    final caixaAntigo = Caixa(
      total: 10,
      quantidade: 1,
      porFormaPagamento: const {},
    );

    // A resposta da chamada NOVA (geração 3) chega primeiro...
    respostas[2].complete(caixa);
    await chamadaNova;
    expect(viewModel.caixa, caixa);

    // ...e só depois a resposta da chamada ANTIGA (geração 2) chega — não
    // deve sobrescrever o estado já assumido pela mais nova.
    respostas[1].complete(caixaAntigo);
    await chamadaAntiga;

    expect(viewModel.caixa, caixa);
    expect(viewModel.status, CaixaStatus.sucesso);

    // Geração 1 (do construtor) nunca respondeu; resolve para não deixar
    // o Completer pendente no fim do teste.
    respostas[0].complete(caixaAntigo);
  });

  test(
    'notificar depois de dispose() não lança (guard de BaseViewModel)',
    () async {
      final respostaControlada = Completer<Caixa>();
      when(
        repository.consultarDia(any),
      ).thenAnswer((_) => respostaControlada.future);

      final viewModel = CaixaViewModel(repository);

      viewModel.dispose();
      respostaControlada.complete(caixa);

      // O carregar() disparado no construtor ainda está em voo; sua
      // continuação não deve lançar ao tentar notificar um VM já descartado.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('toda transição de carregar notifica listeners', () async {
    when(repository.consultarDia(any)).thenAnswer((_) async => caixa);

    final viewModel = CaixaViewModel(repository);

    var notificacoes = 0;
    viewModel.addListener(() => notificacoes++);

    final future = viewModel.carregar();
    expect(viewModel.status, CaixaStatus.carregando);

    await future;

    expect(viewModel.status, CaixaStatus.sucesso);
    expect(notificacoes, greaterThanOrEqualTo(2));
  });
}
