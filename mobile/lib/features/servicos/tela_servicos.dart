import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatadores.dart';
import '../../data/models/servico.dart';
import '../../data/repositories/servico_repository.dart';
import 'servicos_view_model.dart';
import 'tela_servico_form.dart';

/// Aba "Serviços": lista os serviços cadastrados (nome/preço/duração), com
/// FAB para criar um novo, tap para editar e ícone de exclusão (com
/// confirmação) por item.
///
/// Cria seu próprio [ServicosViewModel] via [ChangeNotifierProvider], lendo
/// [ServicoRepository] do escopo global (mesmo padrão de `TelaCaixa`). É a
/// única instância do `ServicosViewModel` da aba: ao abrir o formulário
/// (criar/editar), compartilha essa mesma instância via
/// `ChangeNotifierProvider.value` — assim o `salvar` do formulário recarrega
/// a lista já em tela em vez de duplicar uma busca à parte.
class TelaServicos extends StatelessWidget {
  const TelaServicos({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ServicosViewModel(context.read<ServicoRepository>()),
      child: const _TelaServicosConteudo(),
    );
  }
}

class _TelaServicosConteudo extends StatelessWidget {
  const _TelaServicosConteudo();

  void _abrirFormulario(
    BuildContext context,
    ServicosViewModel viewModel, {
    Servico? servico,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: TelaServicoForm(servico: servico),
        ),
      ),
    );
  }

  Future<void> _excluir(
    BuildContext context,
    ServicosViewModel viewModel,
    Servico servico,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir serviço'),
        content: Text('Excluir "${servico.nome}"?'),
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

    final sucesso = await viewModel.excluir(servico.id);
    if (!context.mounted) return;
    if (!sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.mensagemErro ?? 'Erro ao excluir serviço'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServicosViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: _corpo(context, viewModel),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Novo serviço',
            onPressed: () => _abrirFormulario(context, viewModel),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, ServicosViewModel viewModel) {
    switch (viewModel.status) {
      case ServicosStatus.carregando:
        return const Center(child: CircularProgressIndicator());
      case ServicosStatus.erro:
        return Center(
          child: Text(
            viewModel.mensagemErro ?? 'Erro ao carregar os serviços',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      case ServicosStatus.sucesso:
        if (viewModel.servicos.isEmpty) {
          return const Center(child: Text('Nenhum serviço cadastrado'));
        }
        return ListView.builder(
          itemCount: viewModel.servicos.length,
          itemBuilder: (context, indice) {
            final servico = viewModel.servicos[indice];
            return ListTile(
              key: ValueKey(servico.id),
              title: Text(servico.nome),
              subtitle: Text(
                '${formatarPreco(servico.preco)} · '
                '${servico.duracaoMinutos} min',
              ),
              onTap: () =>
                  _abrirFormulario(context, viewModel, servico: servico),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Excluir',
                onPressed: () => _excluir(context, viewModel, servico),
              ),
            );
          },
        );
    }
  }
}
