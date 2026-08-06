import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agendamento_repository.dart';

/// Estado da tela de agenda do dia.
enum AgendaStatus { carregando, sucesso, erro }

/// ViewModel da agenda do dia: busca os agendamentos de [diaSelecionado] via
/// [AgendamentoRepository] e expõe ações de troca de dia e
/// cancelamento/no-show (padrão da seção 7 do MVP doc).
class AgendaViewModel extends ChangeNotifier {
  AgendaViewModel(this._repository) {
    carregar();
  }

  final AgendamentoRepository _repository;

  AgendaStatus status = AgendaStatus.carregando;
  DateTime diaSelecionado = DateTime.now();
  List<Agendamento> agendamentos = [];
  String? mensagemErro;

  /// Mensagem de erro de uma ação pontual (cancelar/no-show), separada de
  /// [mensagemErro] (erro de carregamento da lista inteira). Uma falha aqui
  /// não deve derrubar a lista de agendamentos já carregada com sucesso — a
  /// tela mostra isso via SnackBar/banner e mantém a lista visível.
  String? mensagemErroAcao;

  /// Busca a agenda de [diaSelecionado].
  Future<void> carregar() async {
    status = AgendaStatus.carregando;
    mensagemErro = null;
    notifyListeners();

    try {
      agendamentos = await _repository.buscarAgendaDoDia(diaSelecionado);
      status = AgendaStatus.sucesso;
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = AgendaStatus.erro;
    }
    notifyListeners();
  }

  /// Troca o dia selecionado e recarrega a agenda.
  Future<void> mudarDia(DateTime novoDia) async {
    diaSelecionado = novoDia;
    await carregar();
  }

  /// Cancela/marca não comparecimento do agendamento [id] e recarrega.
  ///
  /// Em caso de falha, expõe [mensagemErroAcao] SEM alterar [status] nem
  /// [agendamentos]: é um erro de ação pontual, não de carregamento da
  /// lista, então a lista já exibida deve permanecer intacta.
  Future<void> cancelar(int id, StatusAgendamento status) async {
    try {
      await _repository.cancelar(id, status);
    } on ApiException catch (e) {
      mensagemErroAcao = e.mensagem;
      notifyListeners();
      return;
    }
    await carregar();
  }

  /// Limpa a mensagem de erro de ação após a tela exibi-la (ex.: SnackBar).
  void limparErroAcao() {
    mensagemErroAcao = null;
  }
}
