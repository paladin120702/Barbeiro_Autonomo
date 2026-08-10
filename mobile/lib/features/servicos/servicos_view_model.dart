import '../../core/base_view_model.dart';
import '../../core/errors/api_exception.dart';
import '../../data/models/servico.dart';
import '../../data/repositories/servico_repository.dart';

/// Estado da lista de serviços.
enum ServicosStatus { carregando, sucesso, erro }

/// ViewModel da aba "Serviços": lista os serviços via [ServicoRepository] e
/// expõe as ações de criar/editar ([salvar]) e remover ([excluir]).
class ServicosViewModel extends BaseViewModel {
  ServicosViewModel(this._repository) {
    carregar();
  }

  final ServicoRepository _repository;

  ServicosStatus status = ServicosStatus.carregando;
  List<Servico> servicos = [];

  /// Mensagem de erro. Usada tanto para falha de [carregar] (aí acompanhada
  /// de `status == erro`) quanto para falha pontual de [salvar]/[excluir]
  /// (aí `status` permanece o que já estava, para não derrubar a lista já
  /// carregada por causa de uma ação pontual em UM serviço).
  String? mensagemErro;

  /// Conta as chamadas de [carregar] para descartar respostas antigas que
  /// cheguem depois de uma mais nova. [salvar]/[excluir] chamam [carregar]
  /// ao final, então duas ações disparadas em sequência rápida (ex.: excluir
  /// dois serviços antes da 1ª resposta voltar) recarregam a lista duas
  /// vezes em paralelo — sem isso, a resposta que chegasse por último
  /// venceria, podendo trazer de volta um serviço já excluído se a resposta
  /// mais antiga chegar depois da mais nova.
  int _geracao = 0;

  /// Busca a lista de serviços.
  Future<void> carregar() async {
    final geracao = ++_geracao;
    status = ServicosStatus.carregando;
    mensagemErro = null;
    notificarSeAtivo();

    List<Servico>? resultado;
    String? erro;
    try {
      resultado = await _repository.listar();
    } on ApiException catch (e) {
      erro = e.mensagem;
    }

    // Uma chamada mais nova já assumiu o estado; esta resposta está velha.
    if (geracao != _geracao) return;

    if (erro != null) {
      mensagemErro = erro;
      status = ServicosStatus.erro;
    } else {
      servicos = resultado!;
      status = ServicosStatus.sucesso;
    }
    notificarSeAtivo();
  }

  /// Cria (sem [id]) ou atualiza (com [id]) um serviço e recarrega a lista.
  ///
  /// Em caso de falha, expõe [mensagemErro] SEM alterar [status] nem
  /// [servicos]: é erro de uma ação pontual, não do carregamento da lista.
  Future<bool> salvar({
    int? id,
    required String nome,
    required double preco,
    required int duracaoMinutos,
  }) async {
    try {
      if (id == null) {
        await _repository.criar(nome, preco, duracaoMinutos);
      } else {
        await _repository.atualizar(id, nome, preco, duracaoMinutos);
      }
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notificarSeAtivo();
      return false;
    }
    await carregar();
    return true;
  }

  /// Exclui o serviço [id] e recarrega a lista.
  ///
  /// Em caso de falha (ex.: backend retorna 400 porque o serviço tem
  /// agendamentos), expõe [mensagemErro] SEM alterar [status] nem
  /// [servicos]: a lista já carregada continua válida.
  Future<bool> excluir(int id) async {
    try {
      await _repository.excluir(id);
    } on ApiException catch (e) {
      mensagemErro = e.mensagem;
      notificarSeAtivo();
      return false;
    }
    await carregar();
    return true;
  }
}
