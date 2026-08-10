import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatadores.dart';
import 'configuracao_view_model.dart';

/// Formulário de criação de uma exceção de horário: date picker + switch
/// "Vou trabalhar neste dia" — desligado (padrão) é folga (`disponivel:
/// false`, sem horas); ligado revela os seletores de hora de início/fim de
/// um horário especial (`disponivel: true`).
///
/// Somente criação: o backend rejeita uma segunda exceção para a mesma data
/// (`ExcecaoHorarioRepository.findByBarbeiroIdAndData`) e não expõe
/// atualização — para mudar uma exceção já criada, a tela de configuração
/// oferece excluir e cadastrar de novo (ver `TelaConfiguracao`).
///
/// Não cria seu próprio [ConfiguracaoViewModel]: usa a mesma instância da
/// tela de configuração (compartilhada via `ChangeNotifierProvider.value`
/// por quem navega até aqui, ver `TelaConfiguracao`).
class TelaExcecaoForm extends StatefulWidget {
  const TelaExcecaoForm({super.key});

  @override
  State<TelaExcecaoForm> createState() => _TelaExcecaoFormState();
}

class _TelaExcecaoFormState extends State<TelaExcecaoForm> {
  late DateTime _data;
  bool _vouTrabalhar = false;
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFim = const TimeOfDay(hour: 18, minute: 0);
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _data = DateTime(hoje.year, hoje.month, hoje.day + 1);
  }

  Future<void> _escolherData(BuildContext context) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

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

    final sucesso = await viewModel.salvarExcecao(
      data: _data,
      disponivel: _vouTrabalhar,
      horaInicio: _vouTrabalhar ? formatarHoraDoDia(_horaInicio) : null,
      horaFim: _vouTrabalhar ? formatarHoraDoDia(_horaFim) : null,
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
    final viewModel = context.read<ConfiguracaoViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Nova exceção')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data'),
              trailing: Text(
                formatarData(_data),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () => _escolherData(context),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vou trabalhar neste dia'),
              value: _vouTrabalhar,
              onChanged: (valor) => setState(() => _vouTrabalhar = valor),
            ),
            if (_vouTrabalhar) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Início'),
                trailing: Text(
                  formatarHoraDoDia(_horaInicio),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _escolherHoraInicio(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fim'),
                trailing: Text(
                  formatarHoraDoDia(_horaFim),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => _escolherHoraFim(context),
              ),
            ],
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
