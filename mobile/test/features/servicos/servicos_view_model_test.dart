import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/models/servico.dart';
import 'package:barbearia_app/data/repositories/servico_repository.dart';
import 'package:barbearia_app/features/servicos/servicos_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'servicos_view_model_test.mocks.dart';

@GenerateMocks([ServicoRepository])
void main() {
  late MockServicoRepository repository;

  const servico = Servico(id: 1, nome: 'Corte', preco: 40, duracaoMinutos: 60);

  setUp(() {
    repository = MockServicoRepository();
  });

  test(
    'carregar com sucesso: status sucesso e lista preenchida, notifica listeners',
    () async {
      when(repository.listar()).thenAnswer((_) async => [servico]);

      final viewModel = ServicosViewModel(repository);
      expect(viewModel.status, ServicosStatus.carregando);

      var notificacoes = 0;
      viewModel.addListener(() => notificacoes++);

      await viewModel.carregar();

      expect(viewModel.status, ServicosStatus.sucesso);
      expect(viewModel.servicos, [servico]);
      expect(notificacoes, greaterThanOrEqualTo(1));
    },
  );

  test(
    'carregar com ApiException: status erro e mensagemErro exposta',
    () async {
      when(repository.listar()).thenAnswer(
        (_) async => throw const ApiException(mensagem: 'Falha ao carregar'),
      );

      final viewModel = ServicosViewModel(repository);
      await viewModel.carregar();

      expect(viewModel.status, ServicosStatus.erro);
      expect(viewModel.mensagemErro, 'Falha ao carregar');
    },
  );

  test(
    'salvar sem id: chama repository.criar, recarrega e retorna true',
    () async {
      when(repository.listar()).thenAnswer((_) async => [servico]);
      when(repository.criar('Corte', 40, 60)).thenAnswer((_) async => servico);

      final viewModel = ServicosViewModel(repository);
      await untilCalled(repository.listar());

      final sucesso = await viewModel.salvar(
        nome: 'Corte',
        preco: 40,
        duracaoMinutos: 60,
      );

      expect(sucesso, isTrue);
      verify(repository.criar('Corte', 40, 60)).called(1);
      verify(repository.listar()).called(2);
    },
  );

  test(
    'salvar com id: chama repository.atualizar, recarrega e retorna true',
    () async {
      when(repository.listar()).thenAnswer((_) async => [servico]);
      when(
        repository.atualizar(1, 'Corte social', 45, 40),
      ).thenAnswer((_) async => servico);

      final viewModel = ServicosViewModel(repository);
      await untilCalled(repository.listar());

      final sucesso = await viewModel.salvar(
        id: 1,
        nome: 'Corte social',
        preco: 45,
        duracaoMinutos: 40,
      );

      expect(sucesso, isTrue);
      verify(repository.atualizar(1, 'Corte social', 45, 40)).called(1);
      verifyNever(repository.criar(any, any, any));
    },
  );

  test('salvar com ApiException: retorna false, expõe mensagemErro e NÃO '
      'destrói status/servicos da lista já carregada', () async {
    when(repository.listar()).thenAnswer((_) async => [servico]);
    when(repository.criar(any, any, any)).thenAnswer(
      (_) async => throw const ApiException(mensagem: 'Nome já existe'),
    );

    final viewModel = ServicosViewModel(repository);
    await untilCalled(repository.listar());
    expect(viewModel.status, ServicosStatus.sucesso);

    final sucesso = await viewModel.salvar(
      nome: 'Corte',
      preco: 40,
      duracaoMinutos: 60,
    );

    expect(sucesso, isFalse);
    expect(viewModel.mensagemErro, 'Nome já existe');
    expect(viewModel.status, ServicosStatus.sucesso);
    expect(viewModel.servicos, [servico]);
    verify(repository.listar()).called(1);
  });

  test(
    'excluir com sucesso: chama repository.excluir, recarrega e retorna true',
    () async {
      when(repository.listar()).thenAnswer((_) async => [servico]);
      when(repository.excluir(1)).thenAnswer((_) async {});

      final viewModel = ServicosViewModel(repository);
      await untilCalled(repository.listar());

      final sucesso = await viewModel.excluir(1);

      expect(sucesso, isTrue);
      verify(repository.excluir(1)).called(1);
      verify(repository.listar()).called(2);
    },
  );

  test(
    'excluir com ApiException (serviço com agendamentos): retorna false, '
    'expõe mensagemErro e NÃO destrói status/servicos da lista já carregada',
    () async {
      when(repository.listar()).thenAnswer((_) async => [servico]);
      when(repository.excluir(1)).thenAnswer(
        (_) async => throw const ApiException(
          statusCode: 400,
          mensagem: 'Serviço possui agendamentos e não pode ser excluído',
        ),
      );

      final viewModel = ServicosViewModel(repository);
      await untilCalled(repository.listar());
      expect(viewModel.status, ServicosStatus.sucesso);

      final sucesso = await viewModel.excluir(1);

      expect(sucesso, isFalse);
      expect(
        viewModel.mensagemErro,
        'Serviço possui agendamentos e não pode ser excluído',
      );
      expect(viewModel.status, ServicosStatus.sucesso);
      expect(viewModel.servicos, [servico]);
      verify(repository.listar()).called(1);
    },
  );

  test('toda transição de carregar notifica listeners', () async {
    when(repository.listar()).thenAnswer((_) async => [servico]);

    final viewModel = ServicosViewModel(repository);

    var notificacoes = 0;
    viewModel.addListener(() => notificacoes++);

    final future = viewModel.carregar();
    expect(viewModel.status, ServicosStatus.carregando);

    await future;

    expect(viewModel.status, ServicosStatus.sucesso);
    expect(notificacoes, greaterThanOrEqualTo(2));
  });
}
