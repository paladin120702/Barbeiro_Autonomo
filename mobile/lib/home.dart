import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'features/agenda/tela_agenda_do_dia.dart';
import 'features/auth/tela_login.dart';
import 'features/caixa/tela_caixa.dart';

/// Shell de navegação pós-login: `BottomNavigationBar` com as 4 áreas do
/// app. Serviços/Config ainda são placeholders — chegam na Task 25/26.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _abaAtual = 0;

  static const _abas = [
    TelaAgendaDoDia(),
    TelaCaixa(),
    _AbaPlaceholder(titulo: 'Serviços'),
    _AbaPlaceholder(titulo: 'Config'),
  ];

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
        onTap: (indice) => setState(() => _abaAtual = indice),
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

class _AbaPlaceholder extends StatelessWidget {
  const _AbaPlaceholder({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(titulo));
  }
}
