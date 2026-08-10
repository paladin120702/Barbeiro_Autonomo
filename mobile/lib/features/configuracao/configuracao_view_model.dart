import '../../core/base_view_model.dart';
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
class ConfiguracaoViewModel extends BaseViewModel {
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

  /// Conta as chamadas de [carregar] para descartar respostas antigas que
  /// cheguem depois de uma mais nova. As quatro ações de escrita chamam
  /// [carregar] ao final, então duas ações disparadas em sequência rápida
  /// (ex.: excluir dois horários antes da 1ª resposta voltar) recarregam as
  /// listas duas vezes em paralelo — sem isso, a resposta que chegasse por
  /// último venceria, podendo trazer de volta um registro já excluído se a
  /// resposta mais antiga chegar depois da mais nova.
  int _geracao = 0;

  /// Busca horários e exceções em paralelo.
  Future<void> carregar() async {
    final geracao = ++_geracao;
    status = ConfiguracaoStatus.carregando;
    mensagemErro = null;
    notificarSeAtivo();

    List<HorarioFuncionamento>? resultadoHorarios;
    List<ExcecaoHorario>? resultadoExcecoes;
    String? erro;
    try {
      final resultados = await Future.wait([
        _repository.listarHorarios(),
        _repository.listarExcecoes(),
      ]);
      resultadoHorarios = resultados[0] as List<HorarioFuncionamento>;
      resultadoExcecoes = resultados[1] as List<ExcecaoHorario>;
    } on ApiException catch (e) {
      erro = e.mensagem;
    }

    // Uma chamada mais nova já assumiu o estado; esta resposta está velha.
    if (geracao != _geracao) return;

    if (erro != null) {
      mensagemErro = erro;
      status = ConfiguracaoStatus.erro;
    } else {
      horarios = resultadoHorarios!;
      excecoes = resultadoExcecoes!;
      status = ConfiguracaoStatus.sucesso;
    }
    notificarSeAtivo();
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
      notificarSeAtivo();
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
      notificarSeAtivo();
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
      notificarSeAtivo();
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
      notificarSeAtivo();
      return false;
    }
    await carregar();
    return true;
  }
}
