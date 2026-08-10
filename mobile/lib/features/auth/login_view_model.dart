import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/repositories/auth_repository.dart';

/// Estado do formulário de login.
///
/// Não existe um valor `sucesso`: o sucesso volta pelo `true` de
/// [LoginViewModel.entrar], consumido uma única vez pela View logo após o
/// `await`, que navega em seguida. Um valor no estado só para dizer "deu
/// certo" ficaria sem leitor — foi o que aconteceu até esta limpeza.
enum LoginStatus { inicial, carregando, erro }

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

    // Volta a `inicial` (e não a um `sucesso` que ninguém leria): o botão
    // deixa de ficar em "entrando…" caso a navegação não aconteça.
    status = LoginStatus.inicial;
    notificarSeAtivo();
    return true;
  }
}
