import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/agendamento_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/caixa_repository.dart';
import 'data/repositories/horario_repository.dart';
import 'data/repositories/servico_repository.dart';
import 'features/agenda/agenda_view_model.dart';
import 'features/agenda/tela_agenda_do_dia.dart';
import 'features/auth/tela_login.dart';
import 'features/caixa/caixa_view_model.dart';
import 'features/caixa/tela_caixa.dart';
import 'features/configuracao/configuracao_view_model.dart';
import 'features/configuracao/tela_configuracao.dart';
import 'features/servicos/servicos_view_model.dart';
import 'features/servicos/tela_servicos.dart';

/// Shell de navegação pós-login: `BottomNavigationBar` com as 4 áreas do
/// app.
///
/// Os ViewModels das abas vivem AQUI, não dentro de cada tela. Como
/// `body` mostra só a aba atual, criá-los na tela fazia a troca de aba
/// descartar o ViewModel: o dia selecionado na Agenda e o período do Caixa
/// voltavam ao padrão a cada ida e volta. Com eles neste nível, o estado
/// sobrevive à troca, e [_HomeConteudo._trocarAba] recarrega a aba de
/// destino explicitamente — preservando a seleção e mantendo os dados
/// frescos (sem isso, finalizar um checkout na Agenda e ir para o Caixa
/// mostraria o faturamento anterior ao pagamento).
///
/// Os providers são preguiçosos: o ViewModel de uma aba só é criado quando
/// ela é aberta pela primeira vez, então entrar no app continua disparando
/// uma requisição (a da Agenda), não quatro.
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) =>
              AgendaViewModel(context.read<AgendamentoRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => CaixaViewModel(context.read<CaixaRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ServicosViewModel(context.read<ServicoRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ConfiguracaoViewModel(context.read<HorarioRepository>()),
        ),
      ],
      child: const _HomeConteudo(),
    );
  }
}

class _HomeConteudo extends StatefulWidget {
  const _HomeConteudo();

  @override
  State<_HomeConteudo> createState() => _HomeConteudoState();
}

class _HomeConteudoState extends State<_HomeConteudo> {
  int _abaAtual = 0;

  /// Abas já abertas ao menos uma vez. Numa aba nova, quem carrega é o
  /// construtor do ViewModel (criado sob demanda pelo provider); recarregar
  /// aqui também dispararia duas requisições na primeira visita.
  final _abasAbertas = <int>{0};

  static const _abas = [
    TelaAgendaDoDia(),
    TelaCaixa(),
    TelaServicos(),
    TelaConfiguracao(),
  ];

  void _trocarAba(int indice) {
    final primeiraVisita = _abasAbertas.add(indice);
    setState(() => _abaAtual = indice);
    if (primeiraVisita) return;

    // Recarrega usando o estado que a aba já tinha (dia selecionado no caso
    // da Agenda, período/referência no caso do Caixa) — nenhuma seleção é
    // perdida.
    switch (indice) {
      case 0:
        context.read<AgendaViewModel>().carregar();
      case 1:
        context.read<CaixaViewModel>().carregar();
      case 2:
        context.read<ServicosViewModel>().carregar();
      case 3:
        context.read<ConfiguracaoViewModel>().carregar();
    }
  }

  Future<void> _sair(BuildContext context) async {
    await context.read<AuthRepository>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const TelaLogin()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbearia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => _sair(context),
          ),
        ],
      ),
      body: _abas[_abaAtual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        onTap: _trocarAba,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Caixa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.content_cut),
            label: 'Serviços',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
        ],
      ),
    );
  }
}
