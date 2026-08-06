import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

/// Estado do formulário de login.
enum LoginStatus { inicial, carregando, sucesso, erro }

/// ViewModel da tela de login: autentica via [AuthRepository] e expõe o
/// estado do formulário (carregando/sucesso/erro) para a View.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repository);

  final AuthRepository _repository;

  LoginStatus status = LoginStatus.inicial;
  String? mensagemErro;

  /// Autentica com [email]/[senha] via [AuthRepository.login].
  Future<void> entrar(String email, String senha) async {
    status = LoginStatus.carregando;
    mensagemErro = null;
    notifyListeners();

    try {
      await _repository.login(email, senha);
      status = LoginStatus.sucesso;
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = LoginStatus.erro;
    }
    notifyListeners();
  }
}
