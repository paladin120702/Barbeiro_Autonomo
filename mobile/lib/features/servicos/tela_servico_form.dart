import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models/servico.dart';
import 'servicos_view_model.dart';

/// Formulário de criação/edição de um serviço.
///
/// Sem [servico]: cria um novo. Com [servico]: edita (`salvar` recebe o
/// `id`). Valida localmente no `Form` (nome obrigatório, preço > 0) antes de
/// chamar [ServicosViewModel.salvar]; em sucesso, faz `pop()`; em falha,
/// mostra a [ServicosViewModel.mensagemErro] num `SnackBar` e mantém o
/// formulário aberto para nova tentativa.
///
/// Não cria seu próprio [ServicosViewModel]: usa a mesma instância da tela
/// de lista (compartilhada via `ChangeNotifierProvider.value` por quem
/// navega até aqui, ver `TelaServicos`), pra recarregar a lista existente em
/// vez de duplicar uma busca inicial e desincronizar dela.
class TelaServicoForm extends StatefulWidget {
  const TelaServicoForm({super.key, this.servico});

  final Servico? servico;

  @override
  State<TelaServicoForm> createState() => _TelaServicoFormState();
}

class _TelaServicoFormState extends State<TelaServicoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _precoController;
  late final TextEditingController _duracaoController;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final servico = widget.servico;
    _nomeController = TextEditingController(text: servico?.nome ?? '');
    _precoController = TextEditingController(
      text: servico == null ? '' : servico.preco.toStringAsFixed(2),
    );
    _duracaoController = TextEditingController(
      text: (servico?.duracaoMinutos ?? 60).toString(),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  String? _validarNome(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe o nome do serviço';
    }
    return null;
  }

  String? _validarPreco(String? valor) {
    final preco = double.tryParse((valor ?? '').replaceAll(',', '.'));
    if (preco == null || preco <= 0) {
      return 'Informe um preço maior que zero';
    }
    return null;
  }

  String? _validarDuracao(String? valor) {
    final duracao = int.tryParse(valor ?? '');
    if (duracao == null || duracao <= 0) {
      return 'Informe uma duração maior que zero';
    }
    return null;
  }

  Future<void> _salvar(
    BuildContext context,
    ServicosViewModel viewModel,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);

    final nome = _nomeController.text.trim();
    final preco = double.parse(_precoController.text.replaceAll(',', '.'));
    final duracaoMinutos = int.parse(_duracaoController.text);

    final sucesso = await viewModel.salvar(
      id: widget.servico?.id,
      nome: nome,
      preco: preco,
      duracaoMinutos: duracaoMinutos,
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
    final editando = widget.servico != null;
    final viewModel = context.read<ServicosViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar serviço' : 'Novo serviço')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: _validarNome,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precoController,
                decoration: const InputDecoration(
                  labelText: 'Preço',
                  prefixText: 'R\$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validarPreco,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _duracaoController,
                decoration: const InputDecoration(
                  labelText: 'Duração (minutos)',
                  helperText:
                      'Informativo — o slot de agendamento é sempre de 1h',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validarDuracao,
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
      ),
    );
  }
}
