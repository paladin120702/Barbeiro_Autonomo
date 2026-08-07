import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'features/auth/tela_login.dart';
import 'home.dart';

/// Raiz do app: decide entre [TelaLogin] e [Home] conforme haja sessão
/// salva ([AuthRepository.temSessao]).
class App extends StatelessWidget {
  const App({super.key, required this.navigatorKey});

  /// Compartilhada com `criarDio` (`main.dart`) para navegar de volta ao
  /// login quando a sessão expira, fora da árvore de widgets.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbearia',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: FutureBuilder<bool>(
        future: context.read<AuthRepository>().temSessao(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final logado = snapshot.data ?? false;
          return logado ? const Home() : const TelaLogin();
        },
      ),
    );
  }
}
