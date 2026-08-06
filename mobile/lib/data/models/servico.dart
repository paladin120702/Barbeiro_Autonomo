/// Espelha `ServicoDTO` do backend (Task 6 / `web/src/types/dto.ts`).
class Servico {
  const Servico({
    required this.id,
    required this.nome,
    required this.preco,
    required this.duracaoMinutos,
  });

  final int id;
  final String nome;
  final double preco;
  final int duracaoMinutos;

  factory Servico.fromJson(Map<String, dynamic> json) => Servico(
        id: json['id'] as int,
        nome: json['nome'] as String,
        preco: (json['preco'] as num).toDouble(),
        duracaoMinutos: json['duracaoMinutos'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'preco': preco,
        'duracaoMinutos': duracaoMinutos,
      };
}
