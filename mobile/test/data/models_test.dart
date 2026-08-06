import 'package:barbearia_app/data/models/agendamento.dart';
import 'package:barbearia_app/data/models/caixa.dart';
import 'package:barbearia_app/data/models/enums.dart';
import 'package:barbearia_app/data/models/excecao_horario.dart';
import 'package:barbearia_app/data/models/horario_funcionamento.dart';
import 'package:barbearia_app/data/models/servico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatusAgendamento', () {
    test('fromApi mapeia todos os valores do backend', () {
      expect(StatusAgendamento.fromApi('AGENDADO'), StatusAgendamento.agendado);
      expect(
        StatusAgendamento.fromApi('CONCLUIDO'),
        StatusAgendamento.concluido,
      );
      expect(
        StatusAgendamento.fromApi('CANCELADO'),
        StatusAgendamento.cancelado,
      );
      expect(
        StatusAgendamento.fromApi('NAO_COMPARECEU'),
        StatusAgendamento.naoCompareceu,
      );
    });

    test('toApi é o inverso de fromApi', () {
      for (final status in StatusAgendamento.values) {
        expect(StatusAgendamento.fromApi(status.toApi()), status);
      }
    });
  });

  group('FormaPagamento', () {
    test('fromApi mapeia todos os valores do backend', () {
      expect(FormaPagamento.fromApi('PIX'), FormaPagamento.pix);
      expect(FormaPagamento.fromApi('DINHEIRO'), FormaPagamento.dinheiro);
      expect(FormaPagamento.fromApi('DEBITO'), FormaPagamento.debito);
      expect(FormaPagamento.fromApi('CREDITO'), FormaPagamento.credito);
    });

    test('toApi é o inverso de fromApi', () {
      for (final forma in FormaPagamento.values) {
        expect(FormaPagamento.fromApi(forma.toApi()), forma);
      }
    });
  });

  group('Agendamento.fromJson', () {
    test('parseia JSON real do backend com NAO_COMPARECEU e sem pagamento',
        () {
      final json = {
        'id': 42,
        'dataHoraInicio': '2026-08-10T14:30:00',
        'dataHoraFim': '2026-08-10T15:00:00',
        'status': 'NAO_COMPARECEU',
        'formaPagamento': null,
        'servicoNome': 'Corte',
        'servicoPreco': 50.00,
        'clienteNome': 'João Silva',
        'clienteTelefone': '11999998888',
      };

      final agendamento = Agendamento.fromJson(json);

      expect(agendamento.id, 42);
      expect(
        agendamento.dataHoraInicio,
        DateTime.parse('2026-08-10T14:30:00'),
      );
      expect(agendamento.dataHoraFim, DateTime.parse('2026-08-10T15:00:00'));
      expect(agendamento.status, StatusAgendamento.naoCompareceu);
      expect(agendamento.formaPagamento, isNull);
      expect(agendamento.servicoNome, 'Corte');
      expect(agendamento.servicoPreco, 50.00);
      expect(agendamento.clienteNome, 'João Silva');
      expect(agendamento.clienteTelefone, '11999998888');
    });

    test('parseia JSON com forma de pagamento presente', () {
      final json = {
        'id': 7,
        'dataHoraInicio': '2026-08-11T09:00:00',
        'dataHoraFim': '2026-08-11T09:30:00',
        'status': 'CONCLUIDO',
        'formaPagamento': 'PIX',
        'servicoNome': 'Barba',
        'servicoPreco': 30.5,
        'clienteNome': 'Maria Souza',
        'clienteTelefone': '11988887777',
      };

      final agendamento = Agendamento.fromJson(json);

      expect(agendamento.status, StatusAgendamento.concluido);
      expect(agendamento.formaPagamento, FormaPagamento.pix);
      expect(agendamento.servicoPreco, 30.5);
    });

    test('toJson produz um mapa que o fromJson consegue reler', () {
      final agendamento = Agendamento(
        id: 1,
        dataHoraInicio: DateTime.parse('2026-08-10T14:30:00'),
        dataHoraFim: DateTime.parse('2026-08-10T15:00:00'),
        status: StatusAgendamento.agendado,
        formaPagamento: FormaPagamento.dinheiro,
        servicoNome: 'Corte',
        servicoPreco: 40,
        clienteNome: 'Ana',
        clienteTelefone: '11900000000',
      );

      final relido = Agendamento.fromJson(agendamento.toJson());

      expect(relido.id, agendamento.id);
      expect(relido.dataHoraInicio, agendamento.dataHoraInicio);
      expect(relido.dataHoraFim, agendamento.dataHoraFim);
      expect(relido.status, agendamento.status);
      expect(relido.formaPagamento, agendamento.formaPagamento);
      expect(relido.servicoPreco, agendamento.servicoPreco);
    });
  });

  group('Servico.fromJson', () {
    test('parseia campos simples', () {
      final servico = Servico.fromJson({
        'id': 3,
        'nome': 'Corte + Barba',
        'preco': 65.0,
        'duracaoMinutos': 45,
      });

      expect(servico.id, 3);
      expect(servico.nome, 'Corte + Barba');
      expect(servico.preco, 65.0);
      expect(servico.duracaoMinutos, 45);
    });
  });

  group('HorarioFuncionamento.fromJson', () {
    test('parseia horaInicio/horaFim no formato HH:mm', () {
      final horario = HorarioFuncionamento.fromJson({
        'id': 1,
        'diaSemana': 1,
        'horaInicio': '09:00',
        'horaFim': '18:00',
        'ativo': true,
      });

      expect(horario.diaSemana, 1);
      expect(horario.horaInicio, '09:00');
      expect(horario.horaFim, '18:00');
      expect(horario.ativo, isTrue);
    });
  });

  group('ExcecaoHorario.fromJson', () {
    test('parseia exceção sem disponibilidade (sem horários)', () {
      final excecao = ExcecaoHorario.fromJson({
        'id': 5,
        'data': '2026-12-25',
        'disponivel': false,
        'horaInicio': null,
        'horaFim': null,
      });

      expect(excecao.id, 5);
      expect(excecao.data, DateTime.parse('2026-12-25'));
      expect(excecao.disponivel, isFalse);
      expect(excecao.horaInicio, isNull);
      expect(excecao.horaFim, isNull);
    });

    test('parseia exceção com disponibilidade estendida', () {
      final excecao = ExcecaoHorario.fromJson({
        'id': 6,
        'data': '2026-12-24',
        'disponivel': true,
        'horaInicio': '08:00',
        'horaFim': '12:00',
      });

      expect(excecao.disponivel, isTrue);
      expect(excecao.horaInicio, '08:00');
      expect(excecao.horaFim, '12:00');
    });
  });

  group('Caixa.fromJson', () {
    test('parseia total, quantidade e mapa por forma de pagamento', () {
      final caixa = Caixa.fromJson({
        'total': 350.75,
        'quantidade': 8,
        'porFormaPagamento': {
          'PIX': 200.25,
          'DINHEIRO': 50.5,
          'DEBITO': 100.0,
        },
      });

      expect(caixa.total, 350.75);
      expect(caixa.quantidade, 8);
      expect(caixa.porFormaPagamento[FormaPagamento.pix], 200.25);
      expect(caixa.porFormaPagamento[FormaPagamento.dinheiro], 50.5);
      expect(caixa.porFormaPagamento[FormaPagamento.debito], 100.0);
      expect(caixa.porFormaPagamento.containsKey(FormaPagamento.credito), isFalse);
    });

    test('parseia mapa vazio quando não há movimentação', () {
      final caixa = Caixa.fromJson({
        'total': 0,
        'quantidade': 0,
        'porFormaPagamento': <String, dynamic>{},
      });

      expect(caixa.total, 0);
      expect(caixa.quantidade, 0);
      expect(caixa.porFormaPagamento, isEmpty);
    });
  });
}
