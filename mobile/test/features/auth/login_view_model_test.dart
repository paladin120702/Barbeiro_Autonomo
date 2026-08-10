import 'dart:async';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/data/repositories/auth_repository.dart';
import 'package:barbearia_app/features/auth/login_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'login_view_model_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository repository;
  late LoginViewModel viewModel;

  setUp(() {
    repository = MockAuthRepository();
    viewModel = LoginViewModel(repository);
  });

  test(
    'entrar com sucesso: carregando depois sucesso, notifica listeners',
    () async {
      when(repository.login(any, any)).thenAnswer((_) async {});

      var notificacoes = 0;
      viewModel.addListener(() => notificacoes++);

      final future = viewModel.entrar('teste@teste.com', 'senha123');

      expect(viewModel.status, LoginStatus.carregando);

      final sucesso = await future;

      expect(sucesso, isTrue);
      // Volta a `inicial`, não fica preso em `carregando` — se ficasse, o
      // botão continuaria desabilitado caso a navegação não acontecesse.
      expect(viewModel.status, LoginStatus.inicial);
      expect(notificacoes, greaterThanOrEqualTo(2));
    },
  );

  test('entrar com ApiException: retorna false, status erro e mensagemErro '
      'exposta', () async {
    when(repository.login(any, any)).thenAnswer(
      (_) async =>
          throw const ApiException(mensagem: 'E-mail ou senha inválidos'),
    );

    var notificacoes = 0;
    viewModel.addListener(() => notificacoes++);

    final sucesso = await viewModel.entrar('teste@teste.com', 'senha-errada');

    expect(sucesso, isFalse);
    expect(viewModel.status, LoginStatus.erro);
    expect(viewModel.mensagemErro, 'E-mail ou senha inválidos');
    expect(notificacoes, greaterThanOrEqualTo(2));
  });

  test(
    'notificar depois de dispose() não lança (guard de BaseViewModel)',
    () async {
      final respostaControlada = Completer<void>();
      when(
        repository.login(any, any),
      ).thenAnswer((_) => respostaControlada.future);

      final future = viewModel.entrar('teste@teste.com', 'senha123');

      viewModel.dispose();
      respostaControlada.complete();

      await expectLater(future, completes);
    },
  );
}
