import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/models/excecao_horario.dart';
import '../../data/models/horario_funcionamento.dart';
import '../../data/repositories/horario_repository.dart';

/// Estado da aba "Configuração".
enum ConfiguracaoStatus { carregando, sucesso, erro }

/// ViewModel da aba "Configuração": horário de funcionamento semanal e
/// exceções (folgas/feriados/horários especiais), via [HorarioRepository].
///
/// [carregar] busca as duas listas em paralelo (`Future.wait`). As quatro
/// ações de escrita (`salvarHorario`, `excluirHorario`, `salvarExcecao`,
/// `excluirExcecao`) seguem o mesmo padrão pontual das demais telas de
/// gestão (ver `ServicosViewModel`): sucesso recarrega e retorna `true`;
/// `ApiException` expõe [mensagemErro] e retorna `false` SEM alterar
/// [status]/[horarios]/[excecoes] já carregados — erro de uma ação pontual
/// não deve derrubar a tela inteira.
class ConfiguracaoViewModel extends ChangeNotifier {
  ConfiguracaoViewModel(this._repository) {
    carregar();
  }

  final HorarioRepository _repository;

  ConfiguracaoStatus status = ConfiguracaoStatus.carregando;
  List<HorarioFuncionamento> horarios = [];
  List<ExcecaoHorario> excecoes = [];

  /// Mensagem de erro. Acompanha `status == erro` quando é falha de
  /// [carregar]; em falha pontual de uma das quatro ações de escrita,
  /// `status` permanece o que já estava (ver documentação da classe).
  String? mensagemErro;

  /// Busca horários e exceções em paralelo.
  Future<void> carregar() async {
    status = ConfiguracaoStatus.carregando;
    mensagemErro = null;
    notifyListeners();

    try {
      final resultados = await Future.wait([
        _repository.listarHorarios(),
        _repository.listarExcecoes(),
      ]);
      horarios = resultados[0] as List<HorarioFuncionamento>;
      excecoes = resultados[1] as List<ExcecaoHorario>;
      status = ConfiguracaoStatus.sucesso;
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      status = ConfiguracaoStatus.erro;
    }
    notifyListeners();
  }

  /// Cria (sem [id]) ou atualiza (com [id]) um horário de funcionamento e
  /// recarrega as listas.
  Future<bool> salvarHorario({
    int? id,
    required int diaSemana,
    required String horaInicio,
    required String horaFim,
    bool ativo = true,
  }) async {
    try {
      if (id == null) {
        await _repository.criarHorario(diaSemana, horaInicio, horaFim);
      } else {
        await _repository.atualizarHorario(
          HorarioFuncionamento(
            id: id,
            diaSemana: diaSemana,
            horaInicio: horaInicio,
            horaFim: horaFim,
            ativo: ativo,
          ),
        );
      }
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notifyListeners();
      return false;
    }
    await carregar();
    return true;
  }

  /// Exclui o horário [id] e recarrega as listas.
  Future<bool> excluirHorario(int id) async {
    try {
      await _repository.excluirHorario(id);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notifyListeners();
      return false;
    }
    await carregar();
    return true;
  }

  /// Cria uma exceção de horário para [data] e recarrega as listas.
  ///
  /// [disponivel] `false` é uma folga (dia inteiro fechado, [horaInicio] e
  /// [horaFim] devem vir `null`); [disponivel] `true` com [horaInicio]/
  /// [horaFim] preenchidos é um horário especial naquele dia.
  Future<bool> salvarExcecao({
    required DateTime data,
    required bool disponivel,
    String? horaInicio,
    String? horaFim,
  }) async {
    try {
      await _repository.criarExcecao(data, disponivel, horaInicio, horaFim);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notifyListeners();
      return false;
    }
    await carregar();
    return true;
  }

  /// Exclui a exceção [id] e recarrega as listas.
  Future<bool> excluirExcecao(int id) async {
    try {
      await _repository.excluirExcecao(id);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notifyListeners();
      return false;
    }
    await carregar();
    return true;
  }
}
