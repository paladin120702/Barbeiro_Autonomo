import 'package:dio/dio.dart';

import '../models/servico.dart';
import 'repository_utils.dart';

/// CRUD de serviços oferecidos pelo barbeiro.
class ServicoRepository {
  ServicoRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/app/servicos`.
  Future<List<Servico>> listar() => tratarErros(() async {
        final resposta = await _dio.get<List<dynamic>>('/api/v1/app/servicos');
        return resposta.data!
            .map((item) => Servico.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  /// `POST /api/v1/app/servicos`.
  Future<Servico> criar(String nome, double preco, int duracaoMinutos) =>
      tratarErros(() async {
        final resposta = await _dio.post<Map<String, dynamic>>(
          '/api/v1/app/servicos',
          data: {
            'nome': nome,
            'preco': preco,
            'duracaoMinutos': duracaoMinutos,
          },
        );
        return Servico.fromJson(resposta.data!);
      });

  /// `PUT /api/v1/app/servicos/{id}`.
  Future<Servico> atualizar(
    int id,
    String nome,
    double preco,
    int duracaoMinutos,
  ) =>
      tratarErros(() async {
        final resposta = await _dio.put<Map<String, dynamic>>(
          '/api/v1/app/servicos/$id',
          data: {
            'nome': nome,
            'preco': preco,
            'duracaoMinutos': duracaoMinutos,
          },
        );
        return Servico.fromJson(resposta.data!);
      });

  /// `DELETE /api/v1/app/servicos/{id}`.
  Future<void> excluir(int id) => tratarErros(
        () => _dio.delete<void>('/api/v1/app/servicos/$id'),
      );
}
