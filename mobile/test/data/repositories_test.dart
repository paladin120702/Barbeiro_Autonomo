import 'dart:convert';
import 'dart:typed_data';

import 'package:barbearia_app/core/errors/api_exception.dart';
import 'package:barbearia_app/core/network/api_client.dart';
import 'package:barbearia_app/core/storage/token_storage.dart';
import 'package:barbearia_app/data/models/enums.dart';
import 'package:barbearia_app/data/models/horario_funcionamento.dart';
import 'package:barbearia_app/data/repositories/agendamento_repository.dart';
import 'package:barbearia_app/data/repositories/auth_repository.dart';
import 'package:barbearia_app/data/repositories/caixa_repository.dart';
import 'package:barbearia_app/data/repositories/horario_repository.dart';
import 'package:barbearia_app/data/repositories/servico_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// TokenStorage fake em memória, sem depender de plugin de plataforma
/// (mesma técnica de `test/core/api_client_test.dart`, Task 19).
class FakeTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<void> salvar(String token) async => _token = token;

  @override
  Future<String?> ler() async => _token;

  @override
  Future<void> limpar() async => _token = null;
}

/// Adapter fake: não faz I/O real, devolve a resposta programada e registra
/// a última requisição feita para inspeção nos testes.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, this.body});

  final int statusCode;
  final dynamic body;
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

Dio _dioComAdapter(_FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://localhost'))..httpClientAdapter = adapter;

Map<String, dynamic> _agendamentoJson({int id = 1}) => {
      'id': id,
      'dataHoraInicio': '2026-08-03T10:00:00',
      'dataHoraFim': '2026-08-03T10:30:00',
      'status': 'AGENDADO',
      'formaPagamento': null,
      'servicoNome': 'Corte',
      'servicoPreco': 40.0,
      'clienteNome': 'João',
      'clienteTelefone': '11999999999',
    };

Map<String, dynamic> _servicoJson({int id = 1}) => {
      'id': id,
      'nome': 'Corte',
      'preco': 40.0,
      'duracaoMinutos': 30,
    };

Map<String, dynamic> _horarioJson({int id = 1}) => {
      'id': id,
      'diaSemana': 1,
      'horaInicio': '09:00',
      'horaFim': '18:00',
      'ativo': true,
    };

Map<String, dynamic> _excecaoJson({int id = 1}) => {
      'id': id,
      'data': '2026-12-25',
      'disponivel': false,
      'horaInicio': null,
      'horaFim': null,
    };

Map<String, dynamic> _caixaJson() => {
      'total': 100.0,
      'quantidade': 2,
      'porFormaPagamento': {'PIX': 60.0, 'DINHEIRO': 40.0},
    };

void main() {
  group('AuthRepository', () {
    test('login envia POST /api/v1/app/login com email/senha e salva o token retornado',
        () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {'token': 'token-xyz', 'nome': 'Barbeiro', 'slug': 'barbeiro'},
      );
      final storage = FakeTokenStorage();
      final repo = AuthRepository(_dioComAdapter(adapter), storage);

      await repo.login('a@a.com', 'senha123');

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/login');
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {
        'email': 'a@a.com',
        'senha': 'senha123',
      });
      expect(await storage.ler(), 'token-xyz');
    });

    test('logout limpa o storage', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: {});
      final storage = FakeTokenStorage();
      await storage.salvar('token-existente');
      final repo = AuthRepository(_dioComAdapter(adapter), storage);

      await repo.logout();

      expect(await storage.ler(), isNull);
    });

    test('temSessao reflete se há token salvo no storage', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: {});
      final storage = FakeTokenStorage();
      final repo = AuthRepository(_dioComAdapter(adapter), storage);

      expect(await repo.temSessao(), isFalse);

      await storage.salvar('token-abc');

      expect(await repo.temSessao(), isTrue);
    });
  });

  group('AgendamentoRepository', () {
    test('buscarAgendaDoDia faz GET com data=yyyy-MM-dd e parseia a lista',
        () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: [_agendamentoJson(id: 7)],
      );
      final repo = AgendamentoRepository(_dioComAdapter(adapter));

      final agenda = await repo.buscarAgendaDoDia(DateTime(2026, 8, 3));

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/agendamentos');
      expect(adapter.ultimaRequisicao?.method, 'GET');
      expect(adapter.ultimaRequisicao?.queryParameters['data'], '2026-08-03');
      expect(agenda, hasLength(1));
      expect(agenda.single.id, 7);
      expect(agenda.single.servicoNome, 'Corte');
    });

    test('finalizar envia POST .../{id}/finalizar com {"formaPagamento": "PIX"}',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _agendamentoJson());
      final repo = AgendamentoRepository(_dioComAdapter(adapter));

      await repo.finalizar(7, FormaPagamento.pix);

      expect(
        adapter.ultimaRequisicao?.path,
        '/api/v1/app/agendamentos/7/finalizar',
      );
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {'formaPagamento': 'PIX'});
    });

    test('cancelar envia POST .../{id}/cancelar com {"status": "NAO_COMPARECEU"}',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _agendamentoJson());
      final repo = AgendamentoRepository(_dioComAdapter(adapter));

      await repo.cancelar(7, StatusAgendamento.naoCompareceu);

      expect(
        adapter.ultimaRequisicao?.path,
        '/api/v1/app/agendamentos/7/cancelar',
      );
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {'status': 'NAO_COMPARECEU'});
    });
  });

  group('ServicoRepository', () {
    test('listar faz GET /api/v1/app/servicos e parseia a lista', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: [_servicoJson()]);
      final repo = ServicoRepository(_dioComAdapter(adapter));

      final servicos = await repo.listar();

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/servicos');
      expect(adapter.ultimaRequisicao?.method, 'GET');
      expect(servicos.single.nome, 'Corte');
    });

    test('criar faz POST com nome/preco/duracaoMinutos e retorna o Servico criado',
        () async {
      final adapter =
          _FakeAdapter(statusCode: 201, body: _servicoJson(id: 9));
      final repo = ServicoRepository(_dioComAdapter(adapter));

      final servico = await repo.criar('Barba', 25.5, 20);

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/servicos');
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {
        'nome': 'Barba',
        'preco': 25.5,
        'duracaoMinutos': 20,
      });
      expect(servico.id, 9);
    });

    test('atualizar faz PUT /servicos/{id} e retorna o Servico atualizado',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _servicoJson(id: 3));
      final repo = ServicoRepository(_dioComAdapter(adapter));

      final servico = await repo.atualizar(3, 'Corte + Barba', 55, 45);

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/servicos/3');
      expect(adapter.ultimaRequisicao?.method, 'PUT');
      expect(adapter.ultimaRequisicao?.data, {
        'nome': 'Corte + Barba',
        'preco': 55.0,
        'duracaoMinutos': 45,
      });
      expect(servico.id, 3);
    });

    test('excluir faz DELETE /servicos/{id}', () async {
      final adapter = _FakeAdapter(statusCode: 204, body: null);
      final repo = ServicoRepository(_dioComAdapter(adapter));

      await repo.excluir(3);

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/servicos/3');
      expect(adapter.ultimaRequisicao?.method, 'DELETE');
    });
  });

  group('HorarioRepository', () {
    test('listarHorarios faz GET /api/v1/app/horarios e parseia a lista',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: [_horarioJson()]);
      final repo = HorarioRepository(_dioComAdapter(adapter));

      final horarios = await repo.listarHorarios();

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/horarios');
      expect(adapter.ultimaRequisicao?.method, 'GET');
      expect(horarios.single.horaInicio, '09:00');
    });

    test('criarHorario faz POST com diaSemana/horaInicio/horaFim', () async {
      final adapter =
          _FakeAdapter(statusCode: 201, body: _horarioJson(id: 5));
      final repo = HorarioRepository(_dioComAdapter(adapter));

      final horario = await repo.criarHorario(1, '09:00', '18:00');

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/horarios');
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {
        'diaSemana': 1,
        'horaInicio': '09:00',
        'horaFim': '18:00',
      });
      expect(horario.id, 5);
    });

    test('atualizarHorario faz PUT /horarios/{id} com os dados do horário',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _horarioJson(id: 5));
      final repo = HorarioRepository(_dioComAdapter(adapter));
      const horario = HorarioFuncionamento(
        id: 5,
        diaSemana: 2,
        horaInicio: '08:00',
        horaFim: '17:00',
        ativo: false,
      );

      final atualizado = await repo.atualizarHorario(horario);

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/horarios/5');
      expect(adapter.ultimaRequisicao?.method, 'PUT');
      expect(adapter.ultimaRequisicao?.data, {
        'diaSemana': 2,
        'horaInicio': '08:00',
        'horaFim': '17:00',
        'ativo': false,
      });
      expect(atualizado.id, 5);
    });

    test('excluirHorario faz DELETE /horarios/{id}', () async {
      final adapter = _FakeAdapter(statusCode: 204, body: null);
      final repo = HorarioRepository(_dioComAdapter(adapter));

      await repo.excluirHorario(5);

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/horarios/5');
      expect(adapter.ultimaRequisicao?.method, 'DELETE');
    });

    test('listarExcecoes faz GET /api/v1/app/horarios/excecoes e parseia a lista',
        () async {
      final adapter = _FakeAdapter(statusCode: 200, body: [_excecaoJson()]);
      final repo = HorarioRepository(_dioComAdapter(adapter));

      final excecoes = await repo.listarExcecoes();

      expect(
        adapter.ultimaRequisicao?.path,
        '/api/v1/app/horarios/excecoes',
      );
      expect(adapter.ultimaRequisicao?.method, 'GET');
      expect(excecoes.single.disponivel, isFalse);
    });

    test('criarExcecao faz POST com data/disponivel/horaInicio/horaFim',
        () async {
      final adapter =
          _FakeAdapter(statusCode: 201, body: _excecaoJson(id: 4));
      final repo = HorarioRepository(_dioComAdapter(adapter));

      final excecao =
          await repo.criarExcecao(DateTime(2026, 12, 25), false, null, null);

      expect(
        adapter.ultimaRequisicao?.path,
        '/api/v1/app/horarios/excecoes',
      );
      expect(adapter.ultimaRequisicao?.method, 'POST');
      expect(adapter.ultimaRequisicao?.data, {
        'data': '2026-12-25',
        'disponivel': false,
        'horaInicio': null,
        'horaFim': null,
      });
      expect(excecao.id, 4);
    });

    test('excluirExcecao faz DELETE /horarios/excecoes/{id}', () async {
      final adapter = _FakeAdapter(statusCode: 204, body: null);
      final repo = HorarioRepository(_dioComAdapter(adapter));

      await repo.excluirExcecao(4);

      expect(
        adapter.ultimaRequisicao?.path,
        '/api/v1/app/horarios/excecoes/4',
      );
      expect(adapter.ultimaRequisicao?.method, 'DELETE');
    });
  });

  group('CaixaRepository', () {
    test('consultarDia faz GET com periodo=dia&data=yyyy-MM-dd', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _caixaJson());
      final repo = CaixaRepository(_dioComAdapter(adapter));

      final caixa = await repo.consultarDia(DateTime(2026, 8, 3));

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/caixa');
      expect(adapter.ultimaRequisicao?.queryParameters, {
        'periodo': 'dia',
        'data': '2026-08-03',
      });
      expect(caixa.total, 100.0);
    });

    test('consultarMes faz GET com periodo=mes&data=yyyy-MM', () async {
      final adapter = _FakeAdapter(statusCode: 200, body: _caixaJson());
      final repo = CaixaRepository(_dioComAdapter(adapter));

      final caixa = await repo.consultarMes(DateTime(2026, 8, 3));

      expect(adapter.ultimaRequisicao?.path, '/api/v1/app/caixa');
      expect(adapter.ultimaRequisicao?.queryParameters, {
        'periodo': 'mes',
        'data': '2026-08',
      });
      expect(caixa.quantidade, 2);
    });
  });

  group('tratamento de erros — unwrap centralizado de ApiException', () {
    test('erro do Dio (via criarDio) chega como ApiException direto, não DioException',
        () async {
      final adapter = _FakeAdapter(
        statusCode: 404,
        body: {'erro': 'Serviço não encontrado'},
      );
      final storage = FakeTokenStorage();
      final dio = criarDio(storage, baseUrl: 'http://localhost')
        ..httpClientAdapter = adapter;
      final repo = ServicoRepository(dio);

      await expectLater(
        repo.listar,
        throwsA(isA<ApiException>()),
      );

      try {
        await repo.listar();
        fail('deveria ter lançado ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
        expect(e.mensagem, 'Serviço não encontrado');
      }
    });
  });
}
