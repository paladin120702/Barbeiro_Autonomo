import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'data/repositories/agendamento_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/caixa_repository.dart';
import 'data/repositories/horario_repository.dart';
import 'data/repositories/servico_repository.dart';
import 'features/auth/tela_login.dart';

/// `10.0.2.2` é o alias do host no emulador Android; sobrescrito em builds
/// reais com `--dart-define=API_URL=...`.
const _baseUrlPadrao = 'http://10.0.2.2:8080';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  runApp(
    MultiProvider(
      providers: [
        Provider<TokenStorage>(create: (_) => SecureTokenStorage()),
        Provider<Dio>(
          create: (context) => criarDio(
            context.read<TokenStorage>(),
            baseUrl: const String.fromEnvironment(
              'API_URL',
              defaultValue: _baseUrlPadrao,
            ),
            onSessaoExpirada: () {
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TelaLogin()),
                (route) => false,
              );
            },
          ),
        ),
        Provider<AuthRepository>(
          create: (context) =>
              AuthRepository(context.read<Dio>(), context.read<TokenStorage>()),
        ),
        Provider<AgendamentoRepository>(
          create: (context) => AgendamentoRepository(context.read<Dio>()),
        ),
        Provider<ServicoRepository>(
          create: (context) => ServicoRepository(context.read<Dio>()),
        ),
        Provider<HorarioRepository>(
          create: (context) => HorarioRepository(context.read<Dio>()),
        ),
        Provider<CaixaRepository>(
          create: (context) => CaixaRepository(context.read<Dio>()),
        ),
      ],
      child: App(navigatorKey: navigatorKey),
    ),
  );
}
