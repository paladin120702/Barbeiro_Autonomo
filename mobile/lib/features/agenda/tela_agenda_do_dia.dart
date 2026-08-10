import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatadores.dart';
import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../checkout/tela_checkout.dart';
import 'agenda_view_model.dart';
import 'agendamento_tile.dart';

/// Aba "Agenda": lista os agendamentos de [AgendaViewModel.diaSelecionado]
/// com seletor de dia (setas ±1 dia + `showDatePicker`) e ações de
/// finalizar/cancelar por agendamento (padrão MVP doc seção 7).
///
/// O [AgendaViewModel] vem do `Home` (ver a documentação de lá), não é
/// criado aqui: criado aqui, ele seria descartado a cada troca de aba e o
/// dia selecionado voltaria para hoje.
class TelaAgendaDoDia extends StatelessWidget {
  const TelaAgendaDoDia({super.key});

  @override
  Widget build(BuildContext context) => const _TelaAgendaDoDiaConteudo();
}

class _TelaAgendaDoDiaConteudo extends StatelessWidget {
  const _TelaAgendaDoDiaConteudo();

  Future<void> _escolherData(BuildContext context, AgendaViewModel vm) async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: vm.diaSelecionado,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (novaData != null) {
      await vm.mudarDia(novaData);
    }
  }

  /// Navega ao checkout ("Finalizar e Receber") de [agendamento]. Se o
  /// checkout terminar com sucesso (pop com `true`), recarrega a agenda —
  /// mesmo padrão usado depois de [_cancelar].
  Future<void> _finalizar(
    BuildContext context,
    AgendaViewModel viewModel,
    Agendamento agendamento,
  ) async {
    final sucesso = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TelaCheckout(agendamento: agendamento),
      ),
    );
    if (sucesso == true) {
      await viewModel.carregar();
    }
  }

  /// Cancela via [viewModel] e, se a ação falhar, mostra o erro num
  /// SnackBar sem mexer na lista já carregada (a falha é da ação pontual,
  /// não do carregamento da agenda).
  Future<void> _cancelar(
    BuildContext context,
    AgendaViewModel viewModel,
    int agendamentoId,
    StatusAgendamento status,
  ) async {
    final sucesso = await viewModel.cancelar(agendamentoId, status);
    if (!context.mounted || sucesso) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(viewModel.mensagemErro ?? 'Erro ao cancelar')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgendaViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Dia anterior',
                    onPressed: () => viewModel.mudarDia(
                      viewModel.diaSelecionado.subtract(
                        const Duration(days: 1),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _escolherData(context, viewModel),
                    child: Text(
                      formatarData(viewModel.diaSelecionado),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Próximo dia',
                    onPressed: () => viewModel.mudarDia(
                      viewModel.diaSelecionado.add(const Duration(days: 1)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _corpo(context, viewModel)),
          ],
        );
      },
    );
  }

  Widget _corpo(BuildContext context, AgendaViewModel viewModel) {
    switch (viewModel.status) {
      case AgendaStatus.carregando:
        return const Center(child: CircularProgressIndicator());
      case AgendaStatus.erro:
        return Center(
          child: Text(
            viewModel.mensagemErro ?? 'Erro ao carregar a agenda',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      case AgendaStatus.sucesso:
        if (viewModel.agendamentos.isEmpty) {
          return const Center(child: Text('Nenhum agendamento neste dia'));
        }
        return ListView.builder(
          itemCount: viewModel.agendamentos.length,
          itemBuilder: (context, indice) {
            final agendamento = viewModel.agendamentos[indice];
            return AgendamentoTile(
              agendamento: agendamento,
              aoFinalizar: () => _finalizar(context, viewModel, agendamento),
              aoCancelar: (status) =>
                  _cancelar(context, viewModel, agendamento.id, status),
            );
          },
        );
    }
  }
}
