import 'package:dio/dio.dart';

import '../errors/api_exception.dart';
import '../storage/token_storage.dart';

/// Cria um [Dio] configurado com o [baseUrl] da API e um interceptor que:
/// - anexa `Authorization: Bearer <token>` nas requisições (exceto `/login`)
///   quando há um token salvo em [storage];
/// - em erro 401 numa rota `/app` (exceto `/login`), limpa o token salvo e
///   chama [onSessaoExpirada];
/// - sempre converte o [DioException] recebido num [ApiException], extraindo
///   a mensagem do corpo `{"erro": ...}` da resposta quando disponível.
Dio criarDio(
  TokenStorage storage, {
  required String baseUrl,
  void Function()? onSessaoExpirada,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.path.contains('/login')) {
          final token = await storage.ler();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        final path = error.requestOptions.path;
        final ehRotaApp = path.contains('/app') && !path.contains('/login');
        if (error.response?.statusCode == 401 && ehRotaApp) {
          await storage.limpar();
          onSessaoExpirada?.call();
        }

        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: _paraApiException(error),
            stackTrace: error.stackTrace,
          ),
        );
      },
    ),
  );

  return dio;
}

ApiException _paraApiException(DioException error) {
  final statusCode = error.response?.statusCode;
  final data = error.response?.data;
  var mensagem = 'Erro de conexão. Tente novamente.';
  if (data is Map && data['erro'] is String) {
    mensagem = data['erro'] as String;
  }
  Map<String, String>? campos;
  if (data is Map && data['campos'] is Map) {
    campos = (data['campos'] as Map).map(
      (chave, valor) => MapEntry(chave.toString(), valor.toString()),
    );
  }
  // O detalhe por campo entra na própria [mensagem] em vez de depender de
  // cada tela lembrar de ler [campos]: sem isso, o 400 de validação do
  // backend chega ao barbeiro como "Dados inválidos" sem dizer o quê.
  // Compor aqui — ponto único de construção — torna impossível uma tela
  // nova perder o detalhe por esquecimento.
  if (campos != null && campos.isNotEmpty) {
    final detalhes = campos.entries
        .map((entrada) => '${entrada.key} — ${entrada.value}')
        .join('; ');
    mensagem = '$mensagem: $detalhes';
  }
  return ApiException(
    statusCode: statusCode,
    mensagem: mensagem,
    campos: campos,
  );
}
