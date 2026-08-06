import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agendamento_repository.dart';

/// Estado da tela de checkout.
enum CheckoutStatus { inicial, enviando, sucesso, erro }

/// ViewModel do checkout ("Finalizar e Receber"): confirma o pagamento de
/// [agendamento] via [AgendamentoRepository.finalizar] (fluxo da seção 8 do
/// MVP doc).
class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._repository, this.agendamento);

  final AgendamentoRepository _repository;
  final Agendamento agendamento;

  CheckoutStatus status = CheckoutStatus.inicial;
  FormaPagamento? formaSelecionada;
  String? mensagemErro;

  /// Seleciona a forma de pagamento escolhida na tela.
  void selecionarForma(FormaPagamento forma) {
    formaSelecionada = forma;
    notifyListeners();
  }

  /// Confirma o checkout com [formaSelecionada]. Não faz nada se nenhuma
  /// forma foi escolhida ainda (o botão "Confirmar" já fica desabilitado
  /// nesse caso, isto é uma segunda barreira).
  ///
  /// Em caso de falha, [formaSelecionada] é preservada — o barbeiro não
  /// deveria ter que reselecionar a forma de pagamento só para tentar de
  /// novo.
  Future<void> confirmar() async {
    final forma = formaSelecionada;
    if (forma == null) return;

    status = CheckoutStatus.enviando;
    mensagemErro = null;
    notifyListeners();

    try {
      await _repository.finalizar(agendamento.id, forma);
      status = CheckoutStatus.sucesso;
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = CheckoutStatus.erro;
    }
    notifyListeners();
  }

  /// Limpa o sinal de erro após a tela exibi-lo (ex.: SnackBar).
  ///
  /// Sem isso, [status] continuaria `erro` indefinidamente e qualquer
  /// rebuild subsequente do `Consumer` — como o disparado por
  /// [selecionarForma] ao trocar a forma de pagamento pra tentar de novo —
  /// reexibiria o mesmo SnackBar antigo, mesmo sem uma nova tentativa ter
  /// falhado.
  void limparErro() {
    mensagemErro = null;
    status = CheckoutStatus.inicial;
    notifyListeners();
  }
}
