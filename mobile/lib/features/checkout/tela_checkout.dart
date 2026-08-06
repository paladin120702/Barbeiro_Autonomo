import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/agendamento.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/agendamento_repository.dart';
import 'checkout_view_model.dart';

/// Tela de checkout: "Finalizar e Receber" um agendamento, escolhendo a
/// forma de pagamento (fluxo da seção 8 do MVP doc).
///
/// Cria seu próprio [CheckoutViewModel] via [ChangeNotifierProvider], lendo
/// [AgendamentoRepository] do escopo global (mesmo padrão de `TelaLogin`).
/// Ao concluir com sucesso, faz `pop(true)` para a agenda recarregar a
/// lista.
class TelaCheckout extends StatelessWidget {
  const TelaCheckout({super.key, required this.agendamento});

  final Agendamento agendamento;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          CheckoutViewModel(context.read<AgendamentoRepository>(), agendamento),
      child: const _TelaCheckoutConteudo(),
    );
  }
}

class _TelaCheckoutConteudo extends StatelessWidget {
  const _TelaCheckoutConteudo();

  String _formatarPreco(double preco) =>
      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';

  String _rotuloForma(FormaPagamento forma) => switch (forma) {
    FormaPagamento.pix => 'Pix',
    FormaPagamento.dinheiro => 'Dinheiro',
    FormaPagamento.debito => 'Débito',
    FormaPagamento.credito => 'Crédito',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar e Receber')),
      body: Consumer<CheckoutViewModel>(
        builder: (context, viewModel, child) {
          final agendamento = viewModel.agendamento;
          final enviando = viewModel.status == CheckoutStatus.enviando;

          if (viewModel.status == CheckoutStatus.sucesso) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).pop(true);
            });
          }

          if (viewModel.status == CheckoutStatus.erro &&
              viewModel.mensagemErro != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(viewModel.mensagemErro!)));
              viewModel.limparErro();
            });
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agendamento.clienteNome,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(agendamento.servicoNome),
                const SizedBox(height: 4),
                Text(
                  _formatarPreco(agendamento.servicoPreco),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Forma de pagamento',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BotaoForma(
                      forma: FormaPagamento.pix,
                      rotulo: _rotuloForma(FormaPagamento.pix),
                      viewModel: viewModel,
                      enviando: enviando,
                    ),
                    const SizedBox(width: 8),
                    _BotaoForma(
                      forma: FormaPagamento.dinheiro,
                      rotulo: _rotuloForma(FormaPagamento.dinheiro),
                      viewModel: viewModel,
                      enviando: enviando,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BotaoForma(
                      forma: FormaPagamento.debito,
                      rotulo: _rotuloForma(FormaPagamento.debito),
                      viewModel: viewModel,
                      enviando: enviando,
                    ),
                    const SizedBox(width: 8),
                    _BotaoForma(
                      forma: FormaPagamento.credito,
                      rotulo: _rotuloForma(FormaPagamento.credito),
                      viewModel: viewModel,
                      enviando: enviando,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (viewModel.formaSelecionada == null || enviando)
                      ? null
                      : () => viewModel.confirmar(),
                  child: enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Botão de forma de pagamento: destaca a seleção atual de
/// [CheckoutViewModel.formaSelecionada] e delega a escolha para
/// [CheckoutViewModel.selecionarForma]. Sem lógica de negócio própria.
class _BotaoForma extends StatelessWidget {
  const _BotaoForma({
    required this.forma,
    required this.rotulo,
    required this.viewModel,
    required this.enviando,
  });

  final FormaPagamento forma;
  final String rotulo;
  final CheckoutViewModel viewModel;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    final selecionada = viewModel.formaSelecionada == forma;
    final aoTocar = enviando ? null : () => viewModel.selecionarForma(forma);

    return Expanded(
      child: selecionada
          ? ElevatedButton(onPressed: aoTocar, child: Text(rotulo))
          : OutlinedButton(onPressed: aoTocar, child: Text(rotulo)),
    );
  }
}
