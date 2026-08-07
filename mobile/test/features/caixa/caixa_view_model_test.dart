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

  test(
    'inicial: consultarDia é chamado, status sucesso com dados',
    () async {
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
    },
  );

  test(
    'mudarPeriodo(mes) chama consultarMes com a referência atual',
    () async {
      when(repository.consultarDia(any)).thenAnswer((_) async => caixa);
      when(repository.consultarMes(any)).thenAnswer((_) async => caixa);

      final viewModel = CaixaViewModel(repository);
      await untilCalled(repository.consultarDia(any));

      await viewModel.mudarPeriodo(PeriodoCaixa.mes);

      expect(viewModel.periodo, PeriodoCaixa.mes);
      expect(viewModel.status, CaixaStatus.sucesso);
      verify(repository.consultarMes(viewModel.referencia)).called(1);
    },
  );

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
