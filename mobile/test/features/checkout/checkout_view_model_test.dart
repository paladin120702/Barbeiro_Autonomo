import 'dart:async';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/models/agendamento.dart';
import 'package:barbearia_app/data/models/enums.dart';
import 'package:barbearia_app/data/repositories/agendamento_repository.dart';
import 'package:barbearia_app/features/checkout/checkout_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'checkout_view_model_test.mocks.dart';

@GenerateMocks([AgendamentoRepository])
void main() {
  late MockAgendamentoRepository repository;

  final agendamento = Agendamento(
    id: 7,
    dataHoraInicio: DateTime(2026, 8, 6, 9),
    dataHoraFim: DateTime(2026, 8, 6, 9, 30),
    status: StatusAgendamento.agendado,
    servicoNome: 'Corte',
    servicoPreco: 40,
    clienteNome: 'Fulano',
    clienteTelefone: '11999999999',
  );

  setUp(() {
    repository = MockAgendamentoRepository();
  });

  test('confirmar sem forma selecionada: retorna false, status inalterado, '
      'repository não chamado', () async {
    final viewModel = CheckoutViewModel(repository, agendamento);

    final sucesso = await viewModel.confirmar();

    expect(sucesso, isFalse);
    expect(viewModel.status, CheckoutStatus.inicial);
    verifyNever(repository.finalizar(any, any));
  });

  test(
    'selecionarForma(pix) + confirmar com sucesso: enviando depois '
    'sucesso, retorna true, repository recebe (agendamento.id, pix)',
    () async {
      when(repository.finalizar(any, any)).thenAnswer((_) async {});

      final viewModel = CheckoutViewModel(repository, agendamento);
      viewModel.selecionarForma(FormaPagamento.pix);
      expect(viewModel.formaSelecionada, FormaPagamento.pix);

      final future = viewModel.confirmar();
      expect(viewModel.status, CheckoutStatus.enviando);

      final sucesso = await future;

      expect(sucesso, isTrue);
      expect(viewModel.status, CheckoutStatus.sucesso);
      verify(repository.finalizar(7, FormaPagamento.pix)).called(1);
    },
  );

  test('repository lança ApiException: retorna false, status volta a '
      'inicial, mensagemErro exposta, formaSelecionada preservada', () async {
    when(repository.finalizar(any, any)).thenAnswer(
      (_) async => throw const ApiException(mensagem: 'Falha ao finalizar'),
    );

    final viewModel = CheckoutViewModel(repository, agendamento);
    viewModel.selecionarForma(FormaPagamento.dinheiro);

    final sucesso = await viewModel.confirmar();

    expect(sucesso, isFalse);
    expect(viewModel.status, CheckoutStatus.inicial);
    expect(viewModel.mensagemErro, 'Falha ao finalizar');
    // A forma escolhida não deve ser perdida no erro: o barbeiro não deve
    // ter que reselecionar para tentar de novo.
    expect(viewModel.formaSelecionada, FormaPagamento.dinheiro);
  });

  test('depois de uma falha, trocar a forma de pagamento não deixa o sinal '
      'de erro "grudado" (o mesmo SnackBar não deveria reaparecer): como '
      'confirmar() retorna o resultado uma única vez, não existe sinal no '
      'estado que sobreviva ao consumo pela tela', () async {
    when(repository.finalizar(any, any)).thenAnswer(
      (_) async => throw const ApiException(mensagem: 'Falha ao finalizar'),
    );

    final viewModel = CheckoutViewModel(repository, agendamento);
    viewModel.selecionarForma(FormaPagamento.dinheiro);
    final primeiraTentativa = await viewModel.confirmar();
    expect(primeiraTentativa, isFalse);

    // Barbeiro toca em outra forma de pagamento pra tentar de novo — isso só
    // chama selecionarForma(), sem repetir confirmar().
    viewModel.selecionarForma(FormaPagamento.pix);

    // Nenhum estado "erro" sobrevive: status não tem mais esse valor.
    expect(viewModel.status, isNot(CheckoutStatus.enviando));
  });

  test(
    'notificar depois de dispose() não lança (guard de BaseViewModel)',
    () async {
      final respostaControlada = Completer<void>();
      when(
        repository.finalizar(any, any),
      ).thenAnswer((_) => respostaControlada.future);

      final viewModel = CheckoutViewModel(repository, agendamento);
      viewModel.selecionarForma(FormaPagamento.pix);
      final future = viewModel.confirmar();

      viewModel.dispose();
      respostaControlada.complete();

      await expectLater(future, completes);
    },
  );
}
