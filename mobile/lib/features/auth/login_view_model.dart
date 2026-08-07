import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

/// Estado do formulário de login.
enum LoginStatus { inicial, carregando, sucesso, erro }

/// ViewModel da tela de login: autentica via [AuthRepository] e expõe o
/// estado do formulário (carregando/sucesso/erro) para a View.
class LoginViewModel extends BaseViewModel {
  LoginViewModel(this._repository);

  final AuthRepository _repository;

  LoginStatus status = LoginStatus.inicial;
  String? mensagemErro;

  /// Autentica com [email]/[senha] via [AuthRepository.login]. Retorna
  /// `true` em caso de sucesso; a View decide o que fazer com o resultado
  /// (SnackBar/navegação) depois do `await`, sem depender de um sinal de
  /// erro que precisaria ser limpo manualmente do estado.
  Future<bool> entrar(String email, String senha) async {
    status = LoginStatus.carregando;
    mensagemErro = null;
    notificarSeAtivo();

    try {
      await _repository.login(email, senha);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = LoginStatus.erro;
      notificarSeAtivo();
      return false;
    }

    status = LoginStatus.sucesso;
    notificarSeAtivo();
    return true;
  }
}
