import 'package:dio/dio.dart';

import '../models/excecao_horario.dart';
import '../models/horario_funcionamento.dart';
import 'repository_utils.dart';

/// CRUD de horários de funcionamento e exceções (feriados, folgas etc.).
class HorarioRepository {
  HorarioRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/app/horarios`.
  Future<List<HorarioFuncionamento>> listarHorarios() => tratarErros(() async {
        final resposta = await _dio.get<List<dynamic>>('/api/v1/app/horarios');
        return resposta.data!
            .map((item) =>
                HorarioFuncionamento.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  /// `POST /api/v1/app/horarios`.
  Future<HorarioFuncionamento> criarHorario(
    int diaSemana,
    String horaInicio,
    String horaFim,
  ) =>
      tratarErros(() async {
        final resposta = await _dio.post<Map<String, dynamic>>(
          '/api/v1/app/horarios',
          data: {
            'diaSemana': diaSemana,
            'horaInicio': horaInicio,
            'horaFim': horaFim,
          },
        );
        return HorarioFuncionamento.fromJson(resposta.data!);
      });

  /// `PUT /api/v1/app/horarios/{id}`.
  Future<HorarioFuncionamento> atualizarHorario(
    HorarioFuncionamento horario,
  ) =>
      tratarErros(() async {
        final resposta = await _dio.put<Map<String, dynamic>>(
          '/api/v1/app/horarios/${horario.id}',
          data: {
            'diaSemana': horario.diaSemana,
            'horaInicio': horario.horaInicio,
            'horaFim': horario.horaFim,
            'ativo': horario.ativo,
          },
        );
        return HorarioFuncionamento.fromJson(resposta.data!);
      });

  /// `DELETE /api/v1/app/horarios/{id}`.
  Future<void> excluirHorario(int id) => tratarErros(
        () => _dio.delete<void>('/api/v1/app/horarios/$id'),
      );

  /// `GET /api/v1/app/horarios/excecoes`.
  Future<List<ExcecaoHorario>> listarExcecoes() => tratarErros(() async {
        final resposta =
            await _dio.get<List<dynamic>>('/api/v1/app/horarios/excecoes');
        return resposta.data!
            .map((item) => ExcecaoHorario.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  /// `POST /api/v1/app/horarios/excecoes`.
  Future<ExcecaoHorario> criarExcecao(
    DateTime data,
    bool disponivel,
    String? horaInicio,
    String? horaFim,
  ) =>
      tratarErros(() async {
        final resposta = await _dio.post<Map<String, dynamic>>(
          '/api/v1/app/horarios/excecoes',
          data: {
            'data': formatarData(data),
            'disponivel': disponivel,
            'horaInicio': horaInicio,
            'horaFim': horaFim,
          },
        );
        return ExcecaoHorario.fromJson(resposta.data!);
      });

  /// `DELETE /api/v1/app/horarios/excecoes/{id}`.
  Future<void> excluirExcecao(int id) => tratarErros(
        () => _dio.delete<void>('/api/v1/app/horarios/excecoes/$id'),
      );
}
