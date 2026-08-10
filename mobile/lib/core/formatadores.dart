/// Formatadores de exibição compartilhados pelas telas de agenda, checkout,
/// serviços, caixa e configuração.
///
/// Extraídos porque cada tela tinha sua própria cópia de `_formatarPreco`
/// (concatenação manual, sem separador de milhar) enquanto o caixa já usava
/// `NumberFormat` (com separador) — o mesmo valor aparecia formatado
/// diferente em telas diferentes. Também substituem os arrays de nome de
/// mês/dia escritos à mão por `DateFormat` com locale `pt_BR`, já
/// disponível via `intl`/`flutter_localizations` (configurados em
/// `app.dart`).
library;

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:intl/intl.dart';

final _formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _formatoData = DateFormat('dd/MM/yyyy', 'pt_BR');
final _formatoMesAno = DateFormat('MMMM/yyyy', 'pt_BR');
final _formatoDiaSemana = DateFormat('EEEE', 'pt_BR');

/// Formata um valor monetário no padrão pt-BR, com separador de milhar
/// (ex.: `R$ 1.250,00`).
String formatarPreco(num valor) => _formatoMoeda.format(valor);

/// Formata uma data no padrão `dd/MM/yyyy`.
String formatarData(DateTime data) => _formatoData.format(data);

/// Formata mês/ano por extenso, com a inicial maiúscula (ex.: `Agosto/2026`).
String formatarMesAno(DateTime data) => _comInicialMaiuscula(
      _formatoMesAno.format(data),
    );

/// Nome do dia da semana por extenso, com a inicial maiúscula (ex.:
/// `Segunda-feira`). [diaSemana] segue a convenção do backend: `0` domingo …
/// `6` sábado (mesma usada em `HorarioFuncionamento.diaSemana`).
String nomeDiaSemana(int diaSemana) {
  // 2026-08-02 é um domingo; somar diaSemana dias cai no dia da semana
  // certo, sem depender de nenhum dado real além do índice.
  final referencia = DateTime(2026, 8, 2 + diaSemana);
  return _comInicialMaiuscula(_formatoDiaSemana.format(referencia));
}

/// Formata a hora de [data] no padrão `HH:mm`.
String formatarHora(DateTime data) =>
    '${data.hour.toString().padLeft(2, '0')}:'
    '${data.minute.toString().padLeft(2, '0')}';

/// Formata [hora] (um `TimeOfDay`, sem data associada) no padrão `HH:mm`.
String formatarHoraDoDia(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:'
    '${hora.minute.toString().padLeft(2, '0')}';

String _comInicialMaiuscula(String texto) =>
    texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
