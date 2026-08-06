import 'enums.dart';

/// Espelha `CaixaDTO` do backend
/// (`backend/.../caixa/dto/CaixaDTO.java`).
class Caixa {
  const Caixa({
    required this.total,
    required this.quantidade,
    required this.porFormaPagamento,
  });

  final double total;
  final int quantidade;
  final Map<FormaPagamento, double> porFormaPagamento;

  factory Caixa.fromJson(Map<String, dynamic> json) => Caixa(
        total: (json['total'] as num).toDouble(),
        quantidade: json['quantidade'] as int,
        porFormaPagamento:
            (json['porFormaPagamento'] as Map<String, dynamic>).map(
          (chave, valor) => MapEntry(
            FormaPagamento.fromApi(chave),
            (valor as num).toDouble(),
          ),
        ),
      );

  Map<String, dynamic> toJson() => {
        'total': total,
        'quantidade': quantidade,
        'porFormaPagamento': porFormaPagamento.map(
          (chave, valor) => MapEntry(chave.toApi(), valor),
        ),
      };
}
