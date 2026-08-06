/// Espelha a entidade `ExcecaoHorario` do backend
/// (`backend/.../horario/ExcecaoHorario.java`).
///
/// `data` chega como `LocalDate` ISO-8601 (ex.: `"2026-12-25"`), compatível
/// com `DateTime.parse`. `horaInicio`/`horaFim` no formato `"HH:mm"`, iguais
/// a [HorarioFuncionamento].
class ExcecaoHorario {
  const ExcecaoHorario({
    required this.id,
    required this.data,
    required this.disponivel,
    this.horaInicio,
    this.horaFim,
  });

  final int id;
  final DateTime data;
  final bool disponivel;
  final String? horaInicio;
  final String? horaFim;

  factory ExcecaoHorario.fromJson(Map<String, dynamic> json) =>
      ExcecaoHorario(
        id: json['id'] as int,
        data: DateTime.parse(json['data'] as String),
        disponivel: json['disponivel'] as bool,
        horaInicio: json['horaInicio'] as String?,
        horaFim: json['horaFim'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': _formatarData(data),
        'disponivel': disponivel,
        'horaInicio': horaInicio,
        'horaFim': horaFim,
      };

  static String _formatarData(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');
    return '$ano-$mes-$dia';
  }
}
