import 'package:barbearia_app/core/formatadores.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Em produção quem carrega os símbolos de data de `pt_BR` é
/// `flutter_localizations` (via os delegates do `MaterialApp` em `app.dart`).
/// Fora de um `MaterialApp` isso não acontece, e `DateFormat(..., 'pt_BR')`
/// lançaria `ArgumentError: Invalid locale`. Daí o `initializeDateFormatting`
/// aqui — e o registro de que qualquer `testWidgets` futuro que monte
/// `TelaCaixa`/`TelaConfiguracao` precisa dos delegates.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('formatarPreco', () {
    // No padrão pt_BR do `intl`, o separador entre o símbolo e o valor é
    // U+00A0 (espaço não-quebrável), não espaço comum. Montado por código
    // em vez de digitado no literal de propósito: como caractere ele é
    // invisível no editor, e alguém "consertando" pra espaço comum
    // quebraria os testes sem entender o motivo.
    final real = 'R\$${String.fromCharCode(0xa0)}';

    test(
      'usa separador de milhar e vírgula decimal (era o bug: a agenda '
      'mostrava R\$1250,00 e o caixa R\$1.250,00 pro mesmo valor)',
      () {
        expect(formatarPreco(1250), '${real}1.250,00');
        expect(formatarPreco(1250.5), '${real}1.250,50');
      },
    );

    test('valores pequenos e zero', () {
      expect(formatarPreco(0), '${real}0,00');
      expect(formatarPreco(45), '${real}45,00');
      expect(formatarPreco(45.9), '${real}45,90');
    });

    test('arredonda pra 2 casas', () {
      expect(formatarPreco(45.999), '${real}46,00');
    });
  });

  test('formatarData usa dd/MM/yyyy', () {
    expect(formatarData(DateTime(2026, 8, 9)), '09/08/2026');
    expect(formatarData(DateTime(2026, 12, 31)), '31/12/2026');
  });

  test('formatarMesAno usa o mês por extenso com inicial maiúscula', () {
    expect(formatarMesAno(DateTime(2026, 8)), 'Agosto/2026');
    expect(formatarMesAno(DateTime(2026, 3, 15)), 'Março/2026');
  });

  test(
    'nomeDiaSemana cobre os 7 índices na convenção do backend '
    '(0 = domingo até 6 = sábado, igual a HorarioFuncionamento.diaSemana)',
    () {
      expect(
        [for (var dia = 0; dia < 7; dia++) nomeDiaSemana(dia)],
        [
          'Domingo',
          'Segunda-feira',
          'Terça-feira',
          'Quarta-feira',
          'Quinta-feira',
          'Sexta-feira',
          'Sábado',
        ],
      );
    },
  );

  test('formatarHora usa HH:mm com zero à esquerda', () {
    expect(formatarHora(DateTime(2026, 8, 9, 9, 5)), '09:05');
    expect(formatarHora(DateTime(2026, 8, 9, 18, 30)), '18:30');
    expect(formatarHora(DateTime(2026, 8, 9)), '00:00');
  });

  test('formatarHoraDoDia usa HH:mm com zero à esquerda', () {
    expect(formatarHoraDoDia(const TimeOfDay(hour: 9, minute: 5)), '09:05');
    expect(formatarHoraDoDia(const TimeOfDay(hour: 18, minute: 30)), '18:30');
  });
}
