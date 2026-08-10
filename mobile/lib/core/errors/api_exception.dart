/// Exceção de aplicação para erros de chamadas à API.
///
/// [mensagem] é extraída do corpo `{"erro": ...}` da resposta quando
/// disponível; caso contrário, uma mensagem genérica é usada. Quando o corpo
/// também traz [campos], o detalhe por campo já vem embutido em [mensagem]
/// (ver `_paraApiException`) — a tela pode exibi-la direto, sem ler [campos].
class ApiException implements Exception {
  const ApiException({this.statusCode, required this.mensagem, this.campos});

  final int? statusCode;
  final String mensagem;

  /// Erros de validação por campo, extraídos de `{"campos": {"email": "..."}}`
  /// no 400 de validação do backend (`GlobalExceptionHandler.handleValidacao`)
  /// quando presente. `null` nos demais erros (não é sempre um 400 de
  /// validação, e nem todo 400 de validação tem `campos`).
  ///
  /// Guardado em forma estruturada além de embutido em [mensagem] para
  /// permitir, no futuro, marcar o campo errado no próprio formulário.
  final Map<String, String>? campos;

  @override
  String toString() => mensagem;
}
