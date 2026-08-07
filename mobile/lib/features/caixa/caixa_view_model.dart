import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/caixa.dart';
import '../../data/repositories/caixa_repository.dart';

/// Estado da tela de caixa.
enum CaixaStatus { carregando, sucesso, erro }

/// Período consultado: totais do dia ou do mês.
enum PeriodoCaixa { dia, mes }

/// ViewModel da aba "Caixa": consulta os totais recebidos (por forma de
/// pagamento) do [periodo] e [referencia] atuais via [CaixaRepository].
class CaixaViewModel extends ChangeNotifier {
  CaixaViewModel(this._repository) {
    carregar();
  }

  final CaixaRepository _repository;

  CaixaStatus status = CaixaStatus.carregando;
  PeriodoCaixa periodo = PeriodoCaixa.dia;
  DateTime referencia = DateTime.now();
  Caixa? caixa;
  String? mensagemErro;

  /// Consulta o caixa de [referencia] conforme [periodo]: `consultarDia`
  /// para [PeriodoCaixa.dia], `consultarMes` para [PeriodoCaixa.mes].
  Future<void> carregar() async {
    status = CaixaStatus.carregando;
    mensagemErro = null;
    notifyListeners();

    try {
      caixa = periodo == PeriodoCaixa.dia
          ? await _repository.consultarDia(referencia)
          : await _repository.consultarMes(referencia);
      status = CaixaStatus.sucesso;
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = CaixaStatus.erro;
    }
    notifyListeners();
  }

  /// Troca o período (dia/mês) e recarrega.
  Future<void> mudarPeriodo(PeriodoCaixa p) async {
    periodo = p;
    await carregar();
  }

  /// Troca a data/mês de referência e recarrega.
  Future<void> mudarReferencia(DateTime ref) async {
    referencia = ref;
    await carregar();
  }
}
