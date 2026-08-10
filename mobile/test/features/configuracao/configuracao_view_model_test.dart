import 'dart:async';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/models/excecao_horario.dart';
import 'package:barbearia_app/data/models/horario_funcionamento.dart';
import 'package:barbearia_app/data/repositories/horario_repository.dart';
import 'package:barbearia_app/features/configuracao/configuracao_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'configuracao_view_model_test.mocks.dart';

@GenerateMocks([HorarioRepository])
void main() {
  late MockHorarioRepository repository;

  const horario = HorarioFuncionamento(
    id: 1,
    diaSemana: 1,
    horaInicio: '09:00',
    horaFim: '18:00',
    ativo: true,
  );

  final excecao = ExcecaoHorario(
    id: 1,
    data: DateTime(2026, 12, 25),
    disponivel: false,
  );

  setUp(() {
    repository = MockHorarioRepository();
  });

  test(
    'carregar com sucesso: status sucesso, horarios e excecoes preenchidos '
    'via Future.wait dos dois listares',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);

      final viewModel = ConfiguracaoViewModel(repository);
      expect(viewModel.status, ConfiguracaoStatus.carregando);

      // O construtor já dispara 1 carregar(); este await é o 2º.
      await viewModel.carregar();

      expect(viewModel.status, ConfiguracaoStatus.sucesso);
      expect(viewModel.horarios, [horario]);
      expect(viewModel.excecoes, [excecao]);
      verify(repository.listarHorarios()).called(2);
      verify(repository.listarExcecoes()).called(2);
    },
  );

  test(
    'carregar com ApiException (em qualquer um dos dois repositórios): '
    'status erro e mensagemErro exposta',
    () async {
      when(repository.listarHorarios()).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Falha ao carregar'),
      );
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);

      final viewModel = ConfiguracaoViewModel(repository);
      await viewModel.carregar();

      expect(viewModel.status, ConfiguracaoStatus.erro);
      expect(viewModel.mensagemErro, 'Falha ao carregar');
    },
  );

  test(
    'salvarHorario sem id: chama repository.criarHorario, recarrega e '
    'retorna true',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(
        repository.criarHorario(1, '09:00', '18:00'),
      ).thenAnswer((_) async => horario);

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarHorarios());

      final sucesso = await viewModel.salvarHorario(
        diaSemana: 1,
        horaInicio: '09:00',
        horaFim: '18:00',
      );

      expect(sucesso, isTrue);
      verify(repository.criarHorario(1, '09:00', '18:00')).called(1);
      verify(repository.listarHorarios()).called(2);
    },
  );

  test(
    'salvarHorario com id: chama repository.atualizarHorario com o horário '
    'atualizado, recarrega e retorna true',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.atualizarHorario(any)).thenAnswer((_) async => horario);

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarHorarios());

      final sucesso = await viewModel.salvarHorario(
        id: 1,
        diaSemana: 2,
        horaInicio: '08:00',
        horaFim: '17:00',
        ativo: false,
      );

      expect(sucesso, isTrue);
      final capturado =
          verify(repository.atualizarHorario(captureAny)).captured.single
              as HorarioFuncionamento;
      expect(capturado.id, 1);
      expect(capturado.diaSemana, 2);
      expect(capturado.horaInicio, '08:00');
      expect(capturado.horaFim, '17:00');
      expect(capturado.ativo, isFalse);
      verifyNever(repository.criarHorario(any, any, any));
    },
  );

  test(
    'salvarHorario com ApiException: retorna false, expõe mensagemErro e '
    'NÃO destrói status/horarios/excecoes já carregados',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.criarHorario(any, any, any)).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Horário conflita'),
      );

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarHorarios());
      expect(viewModel.status, ConfiguracaoStatus.sucesso);

      final sucesso = await viewModel.salvarHorario(
        diaSemana: 1,
        horaInicio: '09:00',
        horaFim: '18:00',
      );

      expect(sucesso, isFalse);
      expect(viewModel.mensagemErro, 'Horário conflita');
      expect(viewModel.status, ConfiguracaoStatus.sucesso);
      expect(viewModel.horarios, [horario]);
      expect(viewModel.excecoes, [excecao]);
      verify(repository.listarHorarios()).called(1);
    },
  );

  test(
    'excluirHorario com sucesso: chama repository.excluirHorario, recarrega '
    'e retorna true',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.excluirHorario(1)).thenAnswer((_) async {});

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarHorarios());

      final sucesso = await viewModel.excluirHorario(1);

      expect(sucesso, isTrue);
      verify(repository.excluirHorario(1)).called(1);
      verify(repository.listarHorarios()).called(2);
    },
  );

  test(
    'excluirHorario com ApiException: retorna false, expõe mensagemErro e '
    'NÃO destrói status/horarios/excecoes já carregados',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.excluirHorario(1)).thenAnswer(
        (_) async =>
            throw const ApiException(mensagem: 'Não é possível excluir'),
      );

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarHorarios());
      expect(viewModel.status, ConfiguracaoStatus.sucesso);

      final sucesso = await viewModel.excluirHorario(1);

      expect(sucesso, isFalse);
      expect(viewModel.mensagemErro, 'Não é possível excluir');
      expect(viewModel.status, ConfiguracaoStatus.sucesso);
      expect(viewModel.horarios, [horario]);
      verify(repository.listarHorarios()).called(1);
    },
  );

  test(
    'salvarExcecao de folga (disponivel false, horas null): chama '
    'repository.criarExcecao com horaInicio/horaFim null, recarrega e '
    'retorna true',
    () async {
      final data = DateTime(2026, 12, 25);
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(
        repository.criarExcecao(data, false, null, null),
      ).thenAnswer((_) async => excecao);

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarExcecoes());

      final sucesso = await viewModel.salvarExcecao(
        data: data,
        disponivel: false,
      );

      expect(sucesso, isTrue);
      verify(repository.criarExcecao(data, false, null, null)).called(1);
      verify(repository.listarExcecoes()).called(2);
    },
  );

  test(
    'salvarExcecao de horário especial (disponivel true, horas '
    'preenchidas): chama repository.criarExcecao com as horas informadas',
    () async {
      final data = DateTime(2026, 12, 24);
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(
        repository.criarExcecao(data, true, '08:00', '12:00'),
      ).thenAnswer((_) async => excecao);

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarExcecoes());

      final sucesso = await viewModel.salvarExcecao(
        data: data,
        disponivel: true,
        horaInicio: '08:00',
        horaFim: '12:00',
      );

      expect(sucesso, isTrue);
      verify(
        repository.criarExcecao(data, true, '08:00', '12:00'),
      ).called(1);
    },
  );

  test(
    'salvarExcecao com ApiException: retorna false, expõe mensagemErro e '
    'NÃO destrói status/horarios/excecoes já carregados',
    () async {
      final data = DateTime(2026, 12, 25);
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.criarExcecao(any, any, any, any)).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Data inválida'),
      );

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarExcecoes());
      expect(viewModel.status, ConfiguracaoStatus.sucesso);

      final sucesso = await viewModel.salvarExcecao(
        data: data,
        disponivel: false,
      );

      expect(sucesso, isFalse);
      expect(viewModel.mensagemErro, 'Data inválida');
      expect(viewModel.status, ConfiguracaoStatus.sucesso);
      expect(viewModel.excecoes, [excecao]);
      verify(repository.listarExcecoes()).called(1);
    },
  );

  test(
    'excluirExcecao com sucesso: chama repository.excluirExcecao, recarrega '
    'e retorna true',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.excluirExcecao(1)).thenAnswer((_) async {});

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarExcecoes());

      final sucesso = await viewModel.excluirExcecao(1);

      expect(sucesso, isTrue);
      verify(repository.excluirExcecao(1)).called(1);
      verify(repository.listarExcecoes()).called(2);
    },
  );

  test(
    'excluirExcecao com ApiException: retorna false, expõe mensagemErro e '
    'NÃO destrói status/horarios/excecoes já carregados',
    () async {
      when(repository.listarHorarios()).thenAnswer((_) async => [horario]);
      when(repository.listarExcecoes()).thenAnswer((_) async => [excecao]);
      when(repository.excluirExcecao(1)).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Exceção não existe'),
      );

      final viewModel = ConfiguracaoViewModel(repository);
      await untilCalled(repository.listarExcecoes());
      expect(viewModel.status, ConfiguracaoStatus.sucesso);

      final sucesso = await viewModel.excluirExcecao(1);

      expect(sucesso, isFalse);
      expect(viewModel.mensagemErro, 'Exceção não existe');
      expect(viewModel.status, ConfiguracaoStatus.sucesso);
      expect(viewModel.excecoes, [excecao]);
      verify(repository.listarExcecoes()).called(1);
    },
  );

  test(
    'guard de sequenciamento: resposta de uma chamada antiga de carregar() '
    'que chega depois de uma mais nova não sobrescreve o estado (ex.: '
    'excluir um horário e uma exceção antes da 1ª resposta voltar)',
    () async {
      // Cada chamada a listarHorarios/listarExcecoes recebe seu próprio
      // Completer, na ordem em que a chamada foi disparada — permite
      // resolver as respostas fora de ordem para simular a corrida.
      final respostasHorarios = <Completer<List<HorarioFuncionamento>>>[];
      final respostasExcecoes = <Completer<List<ExcecaoHorario>>>[];
      when(repository.listarHorarios()).thenAnswer((_) {
        final completer = Completer<List<HorarioFuncionamento>>();
        respostasHorarios.add(completer);
        return completer.future;
      });
      when(repository.listarExcecoes()).thenAnswer((_) {
        final completer = Completer<List<ExcecaoHorario>>();
        respostasExcecoes.add(completer);
        return completer.future;
      });

      // Geração 1: disparada pelo construtor.
      final viewModel = ConfiguracaoViewModel(repository);
      // Geração 2 (antiga) e geração 3 (nova), disparadas antes de qualquer
      // resposta chegar — como excluir um horário e uma exceção em
      // sequência rápida.
      final chamadaAntiga = viewModel.carregar();
      final chamadaNova = viewModel.carregar();
      expect(respostasHorarios, hasLength(3));
      expect(respostasExcecoes, hasLength(3));

      // A resposta da chamada NOVA (geração 3) chega primeiro...
      respostasHorarios[2].complete([horario]);
      respostasExcecoes[2].complete([excecao]);
      await chamadaNova;
      expect(viewModel.horarios, [horario]);
      expect(viewModel.excecoes, [excecao]);

      // ...e só depois a resposta da chamada ANTIGA (geração 2) chega — não
      // deve sobrescrever o estado já assumido pela mais nova.
      respostasHorarios[1].complete([]);
      respostasExcecoes[1].complete([]);
      await chamadaAntiga;

      expect(viewModel.horarios, [horario]);
      expect(viewModel.excecoes, [excecao]);
      expect(viewModel.status, ConfiguracaoStatus.sucesso);

      // Geração 1 (do construtor) nunca respondeu; resolve para não deixar
      // os Completers pendentes no fim do teste.
      respostasHorarios[0].complete([]);
      respostasExcecoes[0].complete([]);
    },
  );
}
