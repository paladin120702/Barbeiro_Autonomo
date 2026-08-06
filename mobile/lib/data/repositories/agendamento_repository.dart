import 'package:dio/dio.dart';

import '../models/agendamento.dart';
import '../models/enums.dart';
import 'repository_utils.dart';

/// Agenda do dia e ações sobre agendamentos (finalizar/cancelar).
class AgendamentoRepository {
  AgendamentoRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/app/agendamentos?data=yyyy-MM-dd`.
  Future<List<Agendamento>> buscarAgendaDoDia(DateTime dia) =>
      tratarErros(() async {
        final resposta = await _dio.get<List<dynamic>>(
          '/api/v1/app/agendamentos',
          queryParameters: {'data': formatarData(dia)},
        );
        return resposta.data!
            .map((item) => Agendamento.fromJson(item as Map<String, dynamic>))
            .toList();
      });

  /// `POST /api/v1/app/agendamentos/{id}/finalizar`.
  Future<void> finalizar(int id, FormaPagamento forma) =>
      tratarErros(() async {
        await _dio.post<void>(
          '/api/v1/app/agendamentos/$id/finalizar',
          data: {'formaPagamento': forma.toApi()},
        );
      });

  /// `POST /api/v1/app/agendamentos/{id}/cancelar`.
  Future<void> cancelar(int id, StatusAgendamento status) =>
      tratarErros(() async {
        await _dio.post<void>(
          '/api/v1/app/agendamentos/$id/cancelar',
          data: {'status': status.toApi()},
        );
      });
}
