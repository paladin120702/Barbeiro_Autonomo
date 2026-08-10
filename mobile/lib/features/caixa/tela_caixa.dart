import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatadores.dart';
import '../../data/models/enums.dart';
import 'caixa_view_model.dart';

/// Aba "Caixa": totais recebidos por dia ou mês, com o detalhamento por
/// forma de pagamento.
///
/// O [CaixaViewModel] vem do `Home` (ver a documentação de lá), não é criado
/// aqui: criado aqui, ele seria descartado a cada troca de aba e o período
/// dia/mês escolhido voltaria ao padrão.
class TelaCaixa extends StatelessWidget {
  const TelaCaixa({super.key});

  @override
  Widget build(BuildContext context) => const _TelaCaixaConteudo();
}

class _TelaCaixaConteudo extends StatelessWidget {
  const _TelaCaixaConteudo();

  String _formatarReferencia(CaixaViewModel viewModel) =>
      viewModel.periodo == PeriodoCaixa.dia
      ? formatarData(viewModel.referencia)
      : formatarMesAno(viewModel.referencia);

  /// Abre o seletor de data. No período "mês", qualquer dia escolhido dentro
  /// do mês é reduzido para o 1º dia (a referência de [CaixaViewModel] no
  /// período mensal é só ano/mês).
  Future<void> _escolherReferencia(
    BuildContext context,
    CaixaViewModel viewModel,
  ) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: viewModel.referencia,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (escolhida == null) return;
    final novaReferencia = viewModel.periodo == PeriodoCaixa.dia
        ? escolhida
        : DateTime(escolhida.year, escolhida.month);
    await viewModel.mudarReferencia(novaReferencia);
  }

  void _navegarReferencia(CaixaViewModel viewModel, int delta) {
    final novaReferencia = viewModel.periodo == PeriodoCaixa.dia
        ? viewModel.referencia.add(Duration(days: delta))
        : DateTime(
            viewModel.referencia.year,
            viewModel.referencia.month + delta,
          );
    viewModel.mudarReferencia(novaReferencia);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CaixaViewModel>(
      builder: (context, viewModel, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<PeriodoCaixa>(
                segments: const [
                  ButtonSegment(value: PeriodoCaixa.dia, label: Text('Dia')),
                  ButtonSegment(value: PeriodoCaixa.mes, label: Text('Mês')),
                ],
                selected: {viewModel.periodo},
                onSelectionChanged: (selecao) =>
                    viewModel.mudarPeriodo(selecao.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Anterior',
                    onPressed: () => _navegarReferencia(viewModel, -1),
                  ),
                  TextButton(
                    onPressed: () => _escolherReferencia(context, viewModel),
                    child: Text(
                      _formatarReferencia(viewModel),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Próximo',
                    onPressed: () => _navegarReferencia(viewModel, 1),
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

  Widget _corpo(BuildContext context, CaixaViewModel viewModel) {
    switch (viewModel.status) {
      case CaixaStatus.carregando:
        return const Center(child: CircularProgressIndicator());
      case CaixaStatus.erro:
        return Center(
          child: Text(
            viewModel.mensagemErro ?? 'Erro ao carregar o caixa',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      case CaixaStatus.sucesso:
        final caixa = viewModel.caixa;
        if (caixa == null) {
          return const Center(child: Text('Nenhum dado disponível'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              formatarPreco(caixa.total),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${caixa.quantidade} atendimento${caixa.quantidade == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Por forma de pagamento',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Divider(),
            for (final forma in FormaPagamento.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(forma.rotuloExibicao),
                    Text(formatarPreco(caixa.porFormaPagamento[forma] ?? 0)),
                  ],
                ),
              ),
          ],
        );
    }
  }
}
