import 'package:flutter/material.dart';

import '../../core/formatadores.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';

/// Card de um agendamento na agenda do dia: hora, cliente, serviço, preço e
/// badge de status. Agendamentos `AGENDADO` mostram os botões "Finalizar e
/// Receber" e "Cancelar" (tela 7 da seção 7 do MVP doc).
///
/// Sem lógica de negócio: toda ação é delegada às callbacks recebidas, que a
/// tela conecta ao `AgendaViewModel`.
class AgendamentoTile extends StatelessWidget {
  const AgendamentoTile({
    super.key,
    required this.agendamento,
    required this.aoFinalizar,
    required this.aoCancelar,
  });

  final Agendamento agendamento;

  /// Navega ao checkout ("Finalizar e Receber").
  final VoidCallback aoFinalizar;

  /// Chamada com o status escolhido no dialog de cancelamento
  /// ([StatusAgendamento.cancelado] ou [StatusAgendamento.naoCompareceu]).
  final void Function(StatusAgendamento status) aoCancelar;

  Future<void> _abrirDialogCancelamento(BuildContext context) async {
    final status = await showDialog<StatusAgendamento>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar agendamento'),
        content: Text(
          'Cliente: ${agendamento.clienteNome}\n'
          'Telefone: ${agendamento.clienteTelefone}',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(StatusAgendamento.naoCompareceu),
            child: const Text('Cliente não veio'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(StatusAgendamento.cancelado),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );

    if (status != null) {
      aoCancelar(status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agendado = agendamento.status == StatusAgendamento.agendado;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatarHora(agendamento.dataHoraInicio),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    agendamento.clienteNome,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _BadgeStatus(status: agendamento.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${agendamento.servicoNome} · '
              '${formatarPreco(agendamento.servicoPreco)}',
            ),
            if (agendado) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: aoFinalizar,
                      child: const Text('Finalizar e Receber'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _abrirDialogCancelamento(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeStatus extends StatelessWidget {
  const _BadgeStatus({required this.status});

  final StatusAgendamento status;

  (String, Color) get _rotuloECor => switch (status) {
        StatusAgendamento.agendado => ('Agendado', Colors.blue),
        StatusAgendamento.concluido => ('Concluído', Colors.green),
        StatusAgendamento.cancelado => ('Cancelado', Colors.red),
        StatusAgendamento.naoCompareceu => ('Não veio', Colors.orange),
      };

  @override
  Widget build(BuildContext context) {
    final (rotulo, cor) = _rotuloECor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          color: cor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
