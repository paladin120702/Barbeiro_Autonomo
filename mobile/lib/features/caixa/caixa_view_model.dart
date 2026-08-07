import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/caixa.dart';
import '../../data/repositories/caixa_repository.dart';

/// Estado da tela de caixa.
enum CaixaStatus { carregando, sucesso, erro }

/// Período consultado: totais do dia ou do mês.
enum PeriodoCaixa { dia, mes }

/// ViewModel da aba "Caixa": consulta os totais recebidos (por forma de
/// pagamento) do [periodo] e [referencia] atuais via [CaixaRepository].
class CaixaViewModel extends BaseViewModel {
  CaixaViewModel(this._repository) {
    carregar();
  }

  final CaixaRepository _repository;

  CaixaStatus status = CaixaStatus.carregando;
  PeriodoCaixa periodo = PeriodoCaixa.dia;
  DateTime referencia = DateTime.now();
  Caixa? caixa;
  String? mensagemErro;

  /// Conta as chamadas de [carregar] para descartar respostas antigas que
  /// cheguem depois de uma mais nova (ex.: trocar rápido entre dia/mês ou
  /// entre datas de referência). Sem isso, o estado final seria o da
  /// resposta que chegou por último, não o da chamada disparada por último.
  int _geracao = 0;

  /// Consulta o caixa de [referencia] conforme [periodo]: `consultarDia`
  /// para [PeriodoCaixa.dia], `consultarMes` para [PeriodoCaixa.mes].
  Future<void> carregar() async {
    final geracao = ++_geracao;
    status = CaixaStatus.carregando;
    mensagemErro = null;
    notificarSeAtivo();

    Caixa? resultado;
    String? erro;
    try {
      resultado = periodo == PeriodoCaixa.dia
          ? await _repository.consultarDia(referencia)
          : await _repository.consultarMes(referencia);
    } on ApiException catch (e) {
      erro = e.mensagem;
    }

    // Uma chamada mais nova já assumiu o estado; esta resposta está velha.
    if (geracao != _geracao) return;

    if (erro != null) {
      mensagemErro = erro;
      status = CaixaStatus.erro;
    } else {
      caixa = resultado;
      status = CaixaStatus.sucesso;
    }
    notificarSeAtivo();
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
