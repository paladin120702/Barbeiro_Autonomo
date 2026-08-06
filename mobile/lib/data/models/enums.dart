/// Espelha `StatusAgendamento` do backend
/// (`backend/.../agendamento/StatusAgendamento.java`).
enum StatusAgendamento {
  agendado,
  concluido,
  cancelado,
  naoCompareceu;

  static StatusAgendamento fromApi(String valor) {
    switch (valor) {
      case 'AGENDADO':
        return StatusAgendamento.agendado;
      case 'CONCLUIDO':
        return StatusAgendamento.concluido;
      case 'CANCELADO':
        return StatusAgendamento.cancelado;
      case 'NAO_COMPARECEU':
        return StatusAgendamento.naoCompareceu;
      default:
        throw ArgumentError('StatusAgendamento desconhecido: $valor');
    }
  }

  String toApi() {
    switch (this) {
      case StatusAgendamento.agendado:
        return 'AGENDADO';
      case StatusAgendamento.concluido:
        return 'CONCLUIDO';
      case StatusAgendamento.cancelado:
        return 'CANCELADO';
      case StatusAgendamento.naoCompareceu:
        return 'NAO_COMPARECEU';
    }
  }
}

/// Espelha `FormaPagamento` do backend
/// (`backend/.../agendamento/FormaPagamento.java`).
enum FormaPagamento {
  pix,
  dinheiro,
  debito,
  credito;

  static FormaPagamento fromApi(String valor) {
    switch (valor) {
      case 'PIX':
        return FormaPagamento.pix;
      case 'DINHEIRO':
        return FormaPagamento.dinheiro;
      case 'DEBITO':
        return FormaPagamento.debito;
      case 'CREDITO':
        return FormaPagamento.credito;
      default:
        throw ArgumentError('FormaPagamento desconhecida: $valor');
    }
  }

  String toApi() {
    switch (this) {
      case FormaPagamento.pix:
        return 'PIX';
      case FormaPagamento.dinheiro:
        return 'DINHEIRO';
      case FormaPagamento.debito:
        return 'DEBITO';
      case FormaPagamento.credito:
        return 'CREDITO';
    }
  }
}
