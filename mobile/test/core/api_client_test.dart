import 'dart:convert';
import 'dart:typed_data';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/core/network/api_client.dart';
import 'package:barbearia_app/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// TokenStorage fake em memória, sem depender de plugin de plataforma.
class FakeTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> salvar(String token) async => _token = token;

  @override
  Future<String?> ler() async => _token;

  @override
  Future<void> limpar() async => _token = null;
}

/// Adapter fake: não faz I/O real, apenas devolve a resposta programada e
/// registra a última requisição feita para inspeção nos testes.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, Map<String, dynamic>? body})
      : body = body ?? const {};

  final int statusCode;
  final Map<String, dynamic> body;
  RequestOptions? ultimaRequisicao;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaRequisicao = options;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('criarDio - anexação de Authorization', () {
    test('anexa Authorization: Bearer <token> quando há token salvo', () async {
      final storage = FakeTokenStorage();
      await storage.salvar('token-abc');
      final adapter = _FakeAdapter(statusCode: 200, body: {'ok': true});
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;

      await dio.get('/api/v1/app/agendamentos');

      expect(
        adapter.ultimaRequisicao?.headers['Authorization'],
        'Bearer token-abc',
      );
    });

    test('não anexa Authorization quando não há token salvo', () async {
      final storage = FakeTokenStorage();
      final adapter = _FakeAdapter(statusCode: 200, body: {'ok': true});
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;

      await dio.get('/api/v1/app/agendamentos');

      expect(
        adapter.ultimaRequisicao?.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('não anexa Authorization em /login mesmo com token salvo', () async {
      final storage = FakeTokenStorage();
      await storage.salvar('token-abc');
      final adapter = _FakeAdapter(statusCode: 200, body: {'ok': true});
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;

      await dio.post('/api/v1/login');

      expect(
        adapter.ultimaRequisicao?.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('criarDio - sessão expirada', () {
    test('401 em rota /app limpa storage e chama onSessaoExpirada', () async {
      final storage = FakeTokenStorage();
      await storage.salvar('token-expirado');
      var sessaoExpirouChamado = false;
      final adapter =
          _FakeAdapter(statusCode: 401, body: {'erro': 'Sessão expirada'});
      final dio = criarDio(
        storage,
        baseUrl: 'http://localhost',
        onSessaoExpirada: () => sessaoExpirouChamado = true,
      )..httpClientAdapter = adapter;

      await expectLater(
        () => dio.get('/api/v1/app/agendamentos'),
        throwsA(isA<DioException>()),
      );

      expect(sessaoExpirouChamado, isTrue);
      expect(await storage.ler(), isNull);
    });

    test('401 em /login não limpa storage nem chama onSessaoExpirada', () async {
      final storage = FakeTokenStorage();
      await storage.salvar('token-existente');
      var sessaoExpirouChamado = false;
      final adapter = _FakeAdapter(
        statusCode: 401,
        body: {'erro': 'E-mail ou senha inválidos'},
      );
      final dio = criarDio(
        storage,
        baseUrl: 'http://localhost',
        onSessaoExpirada: () => sessaoExpirouChamado = true,
      )..httpClientAdapter = adapter;

      await expectLater(
        () => dio.post('/api/v1/login'),
        throwsA(isA<DioException>()),
      );

      expect(sessaoExpirouChamado, isFalse);
      expect(await storage.ler(), 'token-existente');
    });
  });

  group('criarDio - conversão para ApiException', () {
    test('erro com body {erro: ...} vira ApiException com a mensagem do backend',
        () async {
      final storage = FakeTokenStorage();
      final adapter = _FakeAdapter(
        statusCode: 404,
        body: {'erro': 'Agendamento não encontrado'},
      );
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;

      try {
        await dio.get('/api/v1/app/agendamentos/999');
        fail('deveria ter lançado DioException');
      } on DioException catch (e) {
        expect(e.error, isA<ApiException>());
        final apiException = e.error! as ApiException;
        expect(apiException.statusCode, 404);
        expect(apiException.mensagem, 'Agendamento não encontrado');
      }
    });

    test('erro sem body {erro: ...} vira ApiException com mensagem genérica',
        () async {
      final storage = FakeTokenStorage();
      final adapter =
          _FakeAdapter(statusCode: 500, body: {'outraChave': 'irrelevante'});
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;

      try {
        await dio.get('/api/v1/app/agendamentos');
        fail('deveria ter lançado DioException');
      } on DioException catch (e) {
        final apiException = e.error! as ApiException;
        expect(apiException.statusCode, 500);
        expect(apiException.mensagem, 'Erro de conexão. Tente novamente.');
      }
    });
  });
}
