import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agendamento_repository.dart';

/// Estado da tela de agenda do dia.
enum AgendaStatus { carregando, sucesso, erro }

/// ViewModel da agenda do dia: busca os agendamentos de [diaSelecionado] via
/// [AgendamentoRepository] e expõe ações de troca de dia e
/// cancelamento/no-show (padrão da seção 7 do MVP doc).
class AgendaViewModel extends BaseViewModel {
  AgendaViewModel(this._repository) {
    carregar();
  }

  final AgendamentoRepository _repository;

  AgendaStatus status = AgendaStatus.carregando;
  DateTime diaSelecionado = DateTime.now();
  List<Agendamento> agendamentos = [];
  String? mensagemErro;

  /// Conta as chamadas de [carregar] para descartar respostas antigas que
  /// cheguem depois de uma mais nova (ex.: barbeiro toca a seta de próximo
  /// dia 3x rápido). Sem isso, o estado final seria o da resposta que
  /// chegou por último, não o da chamada disparada por último.
  int _geracao = 0;

  /// Busca a agenda de [diaSelecionado].
  Future<void> carregar() async {
    final geracao = ++_geracao;
    status = AgendaStatus.carregando;
    mensagemErro = null;
    notificarSeAtivo();

    List<Agendamento>? resultado;
    String? erro;
    try {
      resultado = await _repository.buscarAgendaDoDia(diaSelecionado);
    } on ApiException catch (e) {
      erro = e.mensagem;
    }

    // Uma chamada mais nova já assumiu o estado; esta resposta está velha.
    if (geracao != _geracao) return;

    if (erro != null) {
      mensagemErro = erro;
      status = AgendaStatus.erro;
    } else {
      agendamentos = resultado!;
      status = AgendaStatus.sucesso;
    }
    notificarSeAtivo();
  }

  /// Troca o dia selecionado e recarrega a agenda.
  Future<void> mudarDia(DateTime novoDia) async {
    diaSelecionado = novoDia;
    await carregar();
  }

  /// Cancela/marca não comparecimento do agendamento [id] e recarrega.
  ///
  /// Em caso de falha, expõe [mensagemErro] e retorna `false` SEM alterar
  /// [status] nem [agendamentos]: é um erro de ação pontual, não de
  /// carregamento da lista, então a lista já exibida deve permanecer
  /// intacta.
  Future<bool> cancelar(int id, StatusAgendamento status) async {
    try {
      await _repository.cancelar(id, status);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notificarSeAtivo();
      return false;
    }
    await carregar();
    return true;
  }
}
