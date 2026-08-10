import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';
import '../../core/storage/token_storage.dart';
import 'repository_utils.dart';

/// Login e sessão do barbeiro autenticado no app.
class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  /// `POST /api/v1/app/login`; salva o token retornado em [TokenStorage].
  Future<void> login(String email, String senha) => tratarErros(() async {
        final resposta = await _dio.post<Map<String, dynamic>>(
          '/api/v1/app/login',
          data: {'email': email, 'senha': senha},
        );
        // Guardado em vez de `resposta.data!['token'] as String`: um 200 com
        // corpo vazio, sem a chave `token` ou com ela num tipo inesperado
        // lançaria `TypeError` cru, que nenhum ViewModel captura (todos
        // pegam só `ApiException`) — o app quebraria em vez de mostrar erro.
        // (Corpo que nem é um mapa é caso do `tratarErros`, não daqui: o
        // cast falha antes, dentro do dio.)
        final token = resposta.data?['token'];
        if (token is! String || token.isEmpty) {
          throw ApiException(
            statusCode: resposta.statusCode,
            mensagem: 'Resposta de login inválida do servidor.',
          );
        }
        await _storage.salvar(token);
      });

  /// Limpa o token salvo em [TokenStorage].
  Future<void> logout() => _storage.limpar();

  /// `true` se há um token salvo em [TokenStorage].
  Future<bool> temSessao() async => await _storage.ler() != null;
}
