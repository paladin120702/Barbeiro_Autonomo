import 'package:dio/dio.dart';

import '../models/caixa.dart';
import 'repository_utils.dart';

/// Consulta de caixa (totais recebidos) por dia ou por mês.
class CaixaRepository {
  CaixaRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/app/caixa?periodo=dia&data=yyyy-MM-dd`.
  Future<Caixa> consultarDia(DateTime dia) => tratarErros(() async {
        final resposta = await _dio.get<Map<String, dynamic>>(
          '/api/v1/app/caixa',
          queryParameters: {'periodo': 'dia', 'data': formatarData(dia)},
        );
        return Caixa.fromJson(resposta.data!);
      });

  /// `GET /api/v1/app/caixa?periodo=mes&data=yyyy-MM`.
  Future<Caixa> consultarMes(DateTime mesAno) => tratarErros(() async {
        final resposta = await _dio.get<Map<String, dynamic>>(
          '/api/v1/app/caixa',
          queryParameters: {
            'periodo': 'mes',
            'data': formatarMesAno(mesAno),
          },
        );
        return Caixa.fromJson(resposta.data!);
      });
}
