import 'package:dio/dio.dart';

import '../../core/errors/api_exception.dart';

/// Executa [chamada] relançando o [ApiException] embutido em
/// [DioException.error] (colocado lá pelo interceptor de `criarDio`) como
/// exceção direta, para que o código chamador capture com
/// `try/catch (ApiException e)` em vez de lidar com [DioException].
///
/// Ponto único de unwrap compartilhado pelos 5 repositories — evita repetir
/// o cast `e.error as ApiException` em cada método.
Future<T> tratarErros<T>(Future<T> Function() chamada) async {
  try {
    return await chamada();
  } on DioException catch (e) {
    if (e.error is ApiException) {
      throw e.error! as ApiException;
    }
    rethrow;
  }
}

/// Formata [data] como `yyyy-MM-dd` para uso em query params (`?data=...`).
/// Sem dependência de `intl`, conforme o plano.
String formatarData(DateTime data) => data.toIso8601String().substring(0, 10);

/// Formata [data] como `yyyy-MM` para uso em query params de período mensal
/// (`?periodo=mes&data=...`).
String formatarMesAno(DateTime data) =>
    data.toIso8601String().substring(0, 7);
