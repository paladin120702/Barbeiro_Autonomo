import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/horario_funcionamento.dart';
import 'configuracao_view_model.dart';

const _nomesDiasSemana = [
  'Domingo',
  'Segunda-feira',
  'Terça-feira',
  'Quarta-feira',
  'Quinta-feira',
  'Sexta-feira',
  'Sábado',
];

/// Formulário de criação/edição de um horário de funcionamento: dropdown de
/// dia da semana (dom…sáb) + seleção de hora de início/fim via
/// [showTimePicker].
///
/// Sem [horario]: cria um novo (usa [diaSemanaPreset], se informado, como dia
/// inicial do dropdown). Com [horario]: edita (`salvarHorario` recebe o
/// `id`). Em sucesso, faz `pop()`; em falha, mostra
/// [ConfiguracaoViewModel.mensagemErro] num `SnackBar`.
///
/// Não cria seu próprio [ConfiguracaoViewModel]: usa a mesma instância da
/// tela de configuração (compartilhada via `ChangeNotifierProvider.value`
/// por quem navega até aqui, ver `TelaConfiguracao`).
class TelaHorarioForm extends StatefulWidget {
  const TelaHorarioForm({super.key, this.horario, this.diaSemanaPreset});

  final HorarioFuncionamento? horario;
  final int? diaSemanaPreset;

  @override
  State<TelaHorarioForm> createState() => _TelaHorarioFormState();
}

class _TelaHorarioFormState extends State<TelaHorarioForm> {
  late int _diaSemana;
  late TimeOfDay _horaInicio;
  late TimeOfDay _horaFim;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final horario = widget.horario;
    _diaSemana = horario?.diaSemana ?? widget.diaSemanaPreset ?? 1;
    _horaInicio =
        _parseHora(horario?.horaInicio) ?? const TimeOfDay(hour: 9, minute: 0);
    _horaFim =
        _parseHora(horario?.horaFim) ?? const TimeOfDay(hour: 18, minute: 0);
  }

  TimeOfDay? _parseHora(String? hora) {
    if (hora == null) return null;
    final partes = hora.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  String _formatarHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')}';

  Future<void> _escolherHoraInicio(BuildContext context) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _horaInicio,
    );
    if (escolhida != null) setState(() => _horaInicio = escolhida);
  }

  Future<void> _escolherHoraFim(BuildContext context) async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _horaFim,
    );
    if (escolhida != null) setState(() => _horaFim = escolhida);
  }

  Future<void> _salvar(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
  ) async {
    setState(() => _salvando = true);

    final sucesso = await viewModel.salvarHorario(
      id: widget.horario?.id,
      diaSemana: _diaSemana,
      horaInicio: _formatarHora(_horaInicio),
      horaFim: _formatarHora(_horaFim),
      ativo: widget.horario?.ativo ?? true,
    );

    if (!context.mounted) return;

    if (sucesso) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(viewModel.mensagemErro ?? 'Erro ao salvar')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.horario != null;
    final viewModel = context.read<ConfiguracaoViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar horário' : 'Novo horário')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _diaSemana,
              decoration: const InputDecoration(labelText: 'Dia da semana'),
              items: [
                for (var dia = 0; dia < 7; dia++)
                  DropdownMenuItem(
                    value: dia,
                    child: Text(_nomesDiasSemana[dia]),
                  ),
              ],
              onChanged: (dia) {
                if (dia != null) setState(() => _diaSemana = dia);
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Início'),
              trailing: Text(
                _formatarHora(_horaInicio),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _escolherHoraInicio(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fim'),
              trailing: Text(
                _formatarHora(_horaFim),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _escolherHoraFim(context),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _salvando ? null : () => _salvar(context, viewModel),
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
