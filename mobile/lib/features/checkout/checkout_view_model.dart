import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agendamento_repository.dart';

/// Estado da tela de checkout.
///
/// Não existe um valor `erro`: uma falha em [CheckoutViewModel.confirmar]
/// é sinalizada só pelo retorno `false` do método (consumido uma única vez
/// pela View logo após o `await`) e por [CheckoutViewModel.mensagemErro] —
/// o status volta a [CheckoutStatus.inicial], reabilitando o formulário
/// para nova tentativa. Um valor `erro` que sobrevivesse no estado exigiria
/// ser limpo manualmente (como [CheckoutViewModel.confirmar] costumava
/// exigir com um `limparErro()`), reabrindo espaço para o mesmo SnackBar
/// reaparecer num rebuild sem uma nova tentativa ter falhado.
///
/// Pelo mesmo critério não existe `sucesso`: o sucesso volta pelo `true` de
/// [CheckoutViewModel.confirmar], e a View faz `pop` em seguida. O único
/// valor que a tela realmente lê é [CheckoutStatus.enviando], para
/// desabilitar os botões.
enum CheckoutStatus { inicial, enviando }

/// ViewModel do checkout ("Finalizar e Receber"): confirma o pagamento de
/// [agendamento] via [AgendamentoRepository.finalizar] (fluxo da seção 8 do
/// MVP doc).
class CheckoutViewModel extends BaseViewModel {
  CheckoutViewModel(this._repository, this.agendamento);

  final AgendamentoRepository _repository;
  final Agendamento agendamento;

  CheckoutStatus status = CheckoutStatus.inicial;
  FormaPagamento? formaSelecionada;
  String? mensagemErro;

  /// Seleciona a forma de pagamento escolhida na tela.
  void selecionarForma(FormaPagamento forma) {
    formaSelecionada = forma;
    notificarSeAtivo();
  }

  /// Confirma o checkout com [formaSelecionada]. Não faz nada e retorna
  /// `false` se nenhuma forma foi escolhida ainda (o botão "Confirmar" já
  /// fica desabilitado nesse caso, isto é uma segunda barreira).
  ///
  /// Retorna `true` em caso de sucesso; a View decide o que fazer com o
  /// resultado (pop/SnackBar) depois do `await`. Em caso de falha,
  /// [formaSelecionada] é preservada — o barbeiro não deveria ter que
  /// reselecionar a forma de pagamento só para tentar de novo.
  Future<bool> confirmar() async {
    final forma = formaSelecionada;
    if (forma == null) return false;

    status = CheckoutStatus.enviando;
    mensagemErro = null;
    notificarSeAtivo();

    try {
      await _repository.finalizar(agendamento.id, forma);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = CheckoutStatus.inicial;
      notificarSeAtivo();
      return false;
    }

    // Volta a `inicial` (e não a um `sucesso` que ninguém leria): se o `pop`
    // não acontecer, os botões voltam a ficar habilitados em vez de
    // congelados em "enviando".
    status = CheckoutStatus.inicial;
    notificarSeAtivo();
    return true;
  }
}
