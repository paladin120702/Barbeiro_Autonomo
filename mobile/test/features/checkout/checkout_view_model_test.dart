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

  test('confirmar sem forma selecionada: status inalterado, repository não '
      'chamado', () async {
    final viewModel = CheckoutViewModel(repository, agendamento);

    await viewModel.confirmar();

    expect(viewModel.status, CheckoutStatus.inicial);
    verifyNever(repository.finalizar(any, any));
  });

  test('selecionarForma(pix) + confirmar com sucesso: enviando depois sucesso, '
      'repository recebe (agendamento.id, pix)', () async {
    when(repository.finalizar(any, any)).thenAnswer((_) async {});

    final viewModel = CheckoutViewModel(repository, agendamento);
    viewModel.selecionarForma(FormaPagamento.pix);
    expect(viewModel.formaSelecionada, FormaPagamento.pix);

    final future = viewModel.confirmar();
    expect(viewModel.status, CheckoutStatus.enviando);

    await future;

    expect(viewModel.status, CheckoutStatus.sucesso);
    verify(repository.finalizar(7, FormaPagamento.pix)).called(1);
  });

  test('repository lança ApiException: status erro, mensagemErro exposta, '
      'formaSelecionada preservada', () async {
    when(repository.finalizar(any, any)).thenAnswer(
      (_) async => throw const ApiException(mensagem: 'Falha ao finalizar'),
    );

    final viewModel = CheckoutViewModel(repository, agendamento);
    viewModel.selecionarForma(FormaPagamento.dinheiro);

    await viewModel.confirmar();

    expect(viewModel.status, CheckoutStatus.erro);
    expect(viewModel.mensagemErro, 'Falha ao finalizar');
    // A forma escolhida não deve ser perdida no erro: o barbeiro não deve
    // ter que reselecionar para tentar de novo.
    expect(viewModel.formaSelecionada, FormaPagamento.dinheiro);
  });
}
