import 'enums.dart';

/// Espelha `AgendamentoDTO` do backend
/// (`backend/.../agendamento/dto/AgendamentoDTO.java`, Task 11).
///
/// `dataHoraInicio`/`dataHoraFim` chegam como `LocalDateTime` ISO-8601 sem
/// timezone explícito (ex.: `"2026-08-10T14:30:00"`), compatíveis com
/// `DateTime.parse`.
class Agendamento {
  const Agendamento({
    required this.id,
    required this.dataHoraInicio,
    required this.dataHoraFim,
    required this.status,
    this.formaPagamento,
    required this.servicoNome,
    required this.servicoPreco,
    required this.clienteNome,
    required this.clienteTelefone,
  });

  final int id;
  final DateTime dataHoraInicio;
  final DateTime dataHoraFim;
  final StatusAgendamento status;
  final FormaPagamento? formaPagamento;
  final String servicoNome;
  final double servicoPreco;
  final String clienteNome;
  final String clienteTelefone;

  factory Agendamento.fromJson(Map<String, dynamic> json) => Agendamento(
        id: json['id'] as int,
        dataHoraInicio: DateTime.parse(json['dataHoraInicio'] as String),
        dataHoraFim: DateTime.parse(json['dataHoraFim'] as String),
        status: StatusAgendamento.fromApi(json['status'] as String),
        formaPagamento: json['formaPagamento'] == null
            ? null
            : FormaPagamento.fromApi(json['formaPagamento'] as String),
        servicoNome: json['servicoNome'] as String,
        servicoPreco: (json['servicoPreco'] as num).toDouble(),
        clienteNome: json['clienteNome'] as String,
        clienteTelefone: json['clienteTelefone'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dataHoraInicio': dataHoraInicio.toIso8601String(),
        'dataHoraFim': dataHoraFim.toIso8601String(),
        'status': status.toApi(),
        'formaPagamento': formaPagamento?.toApi(),
        'servicoNome': servicoNome,
        'servicoPreco': servicoPreco,
        'clienteNome': clienteNome,
        'clienteTelefone': clienteTelefone,
      };
}
