import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatadores.dart';
import '../../data/models/excecao_horario.dart';
import '../../data/models/horario_funcionamento.dart';
import '../../data/repositories/horario_repository.dart';
import 'configuracao_view_model.dart';
import 'tela_excecao_form.dart';
import 'tela_horario_form.dart';

/// Aba "Configuração": horário de funcionamento semanal (dom…sáb) e exceções
/// futuras (folgas/horários especiais).
///
/// Cria seu próprio [ConfiguracaoViewModel] via [ChangeNotifierProvider],
/// lendo [HorarioRepository] do escopo global (mesmo padrão de
/// `TelaServicos`). É a única instância da aba: ao abrir um formulário
/// (horário ou exceção), compartilha essa mesma instância via
/// `ChangeNotifierProvider.value` — assim `salvarHorario`/`salvarExcecao` do
/// formulário recarregam as listas já em tela.
class TelaConfiguracao extends StatelessWidget {
  const TelaConfiguracao({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          ConfiguracaoViewModel(context.read<HorarioRepository>()),
      child: const _TelaConfiguracaoConteudo(),
    );
  }
}

class _TelaConfiguracaoConteudo extends StatelessWidget {
  const _TelaConfiguracaoConteudo();

  void _abrirFormularioHorario(
    BuildContext context,
    ConfiguracaoViewModel viewModel, {
    HorarioFuncionamento? horario,
    int? diaSemanaPreset,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: TelaHorarioForm(
            horario: horario,
            diaSemanaPreset: diaSemanaPreset,
          ),
        ),
      ),
    );
  }

  void _abrirFormularioExcecao(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: const TelaExcecaoForm(),
        ),
      ),
    );
  }

  Future<void> _excluirHorario(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
    HorarioFuncionamento horario,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir horário'),
        content: Text(
          'Excluir o horário de ${nomeDiaSemana(horario.diaSemana)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final sucesso = await viewModel.excluirHorario(horario.id);
    if (!context.mounted) return;
    if (!sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.mensagemErro ?? 'Erro ao excluir horário'),
        ),
      );
    }
  }

  Future<void> _excluirExcecao(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
    ExcecaoHorario excecao,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir exceção'),
        content: Text('Excluir a exceção de ${formatarData(excecao.data)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final sucesso = await viewModel.excluirExcecao(excecao.id);
    if (!context.mounted) return;
    if (!sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.mensagemErro ?? 'Erro ao excluir exceção'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfiguracaoViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: _corpo(context, viewModel),
          floatingActionButton: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'novo-horario',
                tooltip: 'Novo horário',
                onPressed: viewModel.status == ConfiguracaoStatus.sucesso
                    ? () => _abrirFormularioHorario(context, viewModel)
                    : null,
                icon: const Icon(Icons.schedule),
                label: const Text('Horário'),
              ),
              const SizedBox(width: 16),
              FloatingActionButton.extended(
                heroTag: 'nova-excecao',
                tooltip: 'Nova exceção',
                onPressed: viewModel.status == ConfiguracaoStatus.sucesso
                    ? () => _abrirFormularioExcecao(context, viewModel)
                    : null,
                icon: const Icon(Icons.event_busy),
                label: const Text('Exceção'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, ConfiguracaoViewModel viewModel) {
    switch (viewModel.status) {
      case ConfiguracaoStatus.carregando:
        return const Center(child: CircularProgressIndicator());
      case ConfiguracaoStatus.erro:
        return Center(
          child: Text(
            viewModel.mensagemErro ?? 'Erro ao carregar a configuração',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      case ConfiguracaoStatus.sucesso:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Horário de funcionamento',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            for (var diaSemana = 0; diaSemana < 7; diaSemana++)
              _linhaHorario(context, viewModel, diaSemana),
            const SizedBox(height: 24),
            Text(
              'Exceções futuras',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ..._excecoesFuturas(viewModel).isEmpty
                ? [const Text('Nenhuma exceção futura cadastrada')]
                : _excecoesFuturas(viewModel).map(
                    (excecao) => _linhaExcecao(context, viewModel, excecao),
                  ),
          ],
        );
    }
  }

  List<ExcecaoHorario> _excecoesFuturas(ConfiguracaoViewModel viewModel) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final futuras =
        viewModel.excecoes
            .where((excecao) => !excecao.data.isBefore(hojeSemHora))
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));
    return futuras;
  }

  Widget _linhaHorario(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
    int diaSemana,
  ) {
    // Casa por diaSemana independente de `ativo`: um registro inativo (só
    // possível via seed/DB direto — o app nunca escreve `ativo=false`) ainda
    // precisa aparecer aqui, senão vira órfão inalcançável pela UI — tocar
    // no dia abriria "novo horário" (POST) e criaria um segundo registro
    // para o mesmo dia, já que o backend não valida unicidade por
    // diaSemana. Ver decisão B2 no relatório de backlog.
    final horario = viewModel.horarios.cast<HorarioFuncionamento?>().firstWhere(
      (h) => h != null && h.diaSemana == diaSemana,
      orElse: () => null,
    );
    final fechado = horario == null || !horario.ativo;

    return ListTile(
      key: ValueKey('dia-$diaSemana'),
      title: Text(nomeDiaSemana(diaSemana)),
      subtitle: Text(
        fechado ? 'Fechado' : '${horario.horaInicio} – ${horario.horaFim}',
      ),
      // Com um `horario` (ativo ou não) o tap abre EDIÇÃO daquele registro;
      // só cria um novo quando não existe nenhum registro para o dia.
      onTap: () => _abrirFormularioHorario(
        context,
        viewModel,
        horario: horario,
        diaSemanaPreset: diaSemana,
      ),
      trailing: horario == null
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
              onPressed: () => _excluirHorario(context, viewModel, horario),
            ),
    );
  }

  Widget _linhaExcecao(
    BuildContext context,
    ConfiguracaoViewModel viewModel,
    ExcecaoHorario excecao,
  ) {
    final subtitulo = excecao.disponivel
        ? '${excecao.horaInicio} – ${excecao.horaFim}'
        : 'Folga';

    return ListTile(
      key: ValueKey('excecao-${excecao.id}'),
      title: Text(formatarData(excecao.data)),
      subtitle: Text(subtitulo),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Excluir',
        onPressed: () => _excluirExcecao(context, viewModel, excecao),
      ),
    );
  }
}
