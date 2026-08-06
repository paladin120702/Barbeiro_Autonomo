/// Espelha a entidade `HorarioFuncionamento` do backend
/// (`backend/.../horario/HorarioFuncionamento.java`).
///
/// `horaInicio`/`horaFim` chegam como `String` no formato `"HH:mm"`
/// (serialização de `LocalTime` sem segundos, já que o backend nunca define
/// segundos diferentes de zero para esses campos).
class HorarioFuncionamento {
  const HorarioFuncionamento({
    required this.id,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFim,
    required this.ativo,
  });

  final int id;
  final int diaSemana;
  final String horaInicio;
  final String horaFim;
  final bool ativo;

  factory HorarioFuncionamento.fromJson(Map<String, dynamic> json) =>
      HorarioFuncionamento(
        id: json['id'] as int,
        diaSemana: json['diaSemana'] as int,
        horaInicio: json['horaInicio'] as String,
        horaFim: json['horaFim'] as String,
        ativo: json['ativo'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'diaSemana': diaSemana,
        'horaInicio': horaInicio,
        'horaFim': horaFim,
        'ativo': ativo,
      };
}
