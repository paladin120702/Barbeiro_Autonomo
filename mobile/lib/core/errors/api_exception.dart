/// Exceção de aplicação para erros de chamadas à API.
///
/// [mensagem] é extraída do corpo `{"erro": ...}` da resposta quando
/// disponível; caso contrário, uma mensagem genérica é usada.
class ApiException implements Exception {
  const ApiException({this.statusCode, required this.mensagem});

  final int? statusCode;
  final String mensagem;

  @override
  String toString() => mensagem;
}
