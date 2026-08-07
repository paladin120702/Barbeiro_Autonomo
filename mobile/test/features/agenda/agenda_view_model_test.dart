import 'dart:async';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/models/agendamento.dart';
import 'package:barbearia_app/data/models/enums.dart';
import 'package:barbearia_app/data/repositories/agendamento_repository.dart';
import 'package:barbearia_app/features/agenda/agenda_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'agenda_view_model_test.mocks.dart';

@GenerateMocks([AgendamentoRepository])
void main() {
  late MockAgendamentoRepository repository;

  final agendamento = Agendamento(
    id: 1,
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

  test(
    'carregar com sucesso: status sucesso e lista preenchida, notifica listeners',
    () async {
      when(
        repository.buscarAgendaDoDia(any),
      ).thenAnswer((_) async => [agendamento]);

      final viewModel = AgendaViewModel(repository);
      expect(viewModel.status, AgendaStatus.carregando);

      var notificacoes = 0;
      viewModel.addListener(() => notificacoes++);

      await viewModel.carregar();

      expect(viewModel.status, AgendaStatus.sucesso);
      expect(viewModel.agendamentos, [agendamento]);
      expect(notificacoes, greaterThanOrEqualTo(1));
    },
  );

  test(
    'carregar com ApiException: status erro e mensagemErro exposta',
    () async {
      when(repository.buscarAgendaDoDia(any)).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Falha ao carregar'),
      );

      final viewModel = AgendaViewModel(repository);

      var notificacoes = 0;
      viewModel.addListener(() => notificacoes++);

      await viewModel.carregar();

      expect(viewModel.status, AgendaStatus.erro);
      expect(viewModel.mensagemErro, 'Falha ao carregar');
      expect(notificacoes, greaterThanOrEqualTo(1));
    },
  );

  test('mudarDia chama repository com o novo dia e recarrega', () async {
    when(
      repository.buscarAgendaDoDia(any),
    ).thenAnswer((_) async => [agendamento]);

    final viewModel = AgendaViewModel(repository);
    await untilCalled(repository.buscarAgendaDoDia(any));

    final novoDia = DateTime(2026, 8, 7);
    await viewModel.mudarDia(novoDia);

    expect(viewModel.diaSelecionado, novoDia);
    verify(repository.buscarAgendaDoDia(novoDia)).called(1);
  });

  test(
    'cancelar chama repository com naoCompareceu e recarrega (2x buscarAgendaDoDia)',
    () async {
      when(
        repository.buscarAgendaDoDia(any),
      ).thenAnswer((_) async => [agendamento]);
      when(repository.cancelar(any, any)).thenAnswer((_) async {});

      final viewModel = AgendaViewModel(repository);
      await untilCalled(repository.buscarAgendaDoDia(any));

      final sucesso = await viewModel.cancelar(
        1,
        StatusAgendamento.naoCompareceu,
      );

      expect(sucesso, isTrue);
      verify(repository.cancelar(1, StatusAgendamento.naoCompareceu)).called(1);
      verify(repository.buscarAgendaDoDia(any)).called(2);
    },
  );

  test('cancelar com ApiException: retorna false, NÃO destrói a lista nem o '
      'status de carregamento, expõe mensagemErro (reaproveitado do '
      'carregamento)', () async {
    when(
      repository.buscarAgendaDoDia(any),
    ).thenAnswer((_) async => [agendamento]);
    when(repository.cancelar(any, any)).thenAnswer(
      (_) async => throw const ApiException(mensagem: 'Falha ao cancelar'),
    );

    final viewModel = AgendaViewModel(repository);
    await untilCalled(repository.buscarAgendaDoDia(any));
    expect(viewModel.status, AgendaStatus.sucesso);
    expect(viewModel.agendamentos, [agendamento]);

    final sucesso = await viewModel.cancelar(1, StatusAgendamento.cancelado);

    expect(sucesso, isFalse);
    // A lista e o status de carregamento, já com sucesso, permanecem
    // intactos: a falha foi de uma ação pontual, não do carregamento.
    expect(viewModel.status, AgendaStatus.sucesso);
    expect(viewModel.agendamentos, [agendamento]);
    expect(viewModel.mensagemErro, 'Falha ao cancelar');

    // carregar() não é chamado de novo no caminho de erro (só a 1ª busca
    // inicial do construtor).
    verify(repository.buscarAgendaDoDia(any)).called(1);
  });

  test('guard de sequenciamento: resposta de uma chamada antiga de carregar() '
      'que chega depois de uma mais nova não sobrescreve o estado (ex.: '
      'barbeiro toca a seta de próximo dia 2x rápido e a 1ª resposta chega '
      'por último)', () async {
    // Cada chamada a buscarAgendaDoDia recebe seu próprio Completer, na
    // ordem em que a chamada foi disparada — permite resolver as respostas
    // fora de ordem para simular a corrida.
    final respostas = <Completer<List<Agendamento>>>[];
    when(repository.buscarAgendaDoDia(any)).thenAnswer((_) {
      final completer = Completer<List<Agendamento>>();
      respostas.add(completer);
      return completer.future;
    });

    // Geração 1: disparada pelo construtor.
    final viewModel = AgendaViewModel(repository);
    // Geração 2 (antiga) e geração 3 (nova), disparadas antes de qualquer
    // resposta chegar — como 2 toques rápidos na seta de próximo dia.
    final chamadaAntiga = viewModel.carregar();
    final chamadaNova = viewModel.carregar();
    expect(respostas, hasLength(3));

    // A resposta da chamada NOVA (geração 3) chega primeiro...
    respostas[2].complete([agendamento]);
    await chamadaNova;
    expect(viewModel.agendamentos, [agendamento]);

    // ...e só depois a resposta da chamada ANTIGA (geração 2) chega — não
    // deve sobrescrever o estado já assumido pela mais nova.
    respostas[1].complete([]);
    await chamadaAntiga;

    expect(viewModel.agendamentos, [agendamento]);
    expect(viewModel.status, AgendaStatus.sucesso);

    // Geração 1 (do construtor) nunca respondeu; resolve para não deixar
    // o Completer pendente no fim do teste.
    respostas[0].complete([]);
  });

  test(
    'notificar depois de dispose() não lança (guard de BaseViewModel)',
    () async {
      final respostaControlada = Completer<List<Agendamento>>();
      when(
        repository.buscarAgendaDoDia(any),
      ).thenAnswer((_) => respostaControlada.future);

      final viewModel = AgendaViewModel(repository);

      viewModel.dispose();
      respostaControlada.complete([agendamento]);

      // O carregar() disparado no construtor ainda está em voo; sua
      // continuação não deve lançar ao tentar notificar um VM já descartado.
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('toda transição de carregar notifica listeners', () async {
    when(
      repository.buscarAgendaDoDia(any),
    ).thenAnswer((_) async => [agendamento]);

    final viewModel = AgendaViewModel(repository);

    var notificacoes = 0;
    viewModel.addListener(() => notificacoes++);

    final future = viewModel.carregar();
    expect(viewModel.status, AgendaStatus.carregando);

    await future;

    expect(viewModel.status, AgendaStatus.sucesso);
    expect(notificacoes, greaterThanOrEqualTo(2));
  });
}
