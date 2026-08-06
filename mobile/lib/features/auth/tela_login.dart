import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../home.dart';
import 'login_view_model.dart';

/// Tela de login: formulário de e-mail/senha, consumindo [LoginViewModel].
///
/// Cria seu próprio [LoginViewModel] via [ChangeNotifierProvider] (padrão da
/// seção 7 do MVP doc), lendo [AuthRepository] do escopo global — assim
/// qualquer ponto do app pode navegar para `TelaLogin()` sem repetir o
/// boilerplate de injeção.
class TelaLogin extends StatelessWidget {
  const TelaLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(context.read<AuthRepository>()),
      child: const _TelaLoginForm(),
    );
  }
}

class _TelaLoginForm extends StatefulWidget {
  const _TelaLoginForm();

  @override
  State<_TelaLoginForm> createState() => _TelaLoginFormState();
}

class _TelaLoginFormState extends State<_TelaLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Consumer<LoginViewModel>(
        builder: (context, viewModel, child) {
          final carregando = viewModel.status == LoginStatus.carregando;

          if (viewModel.status == LoginStatus.erro &&
              viewModel.mensagemErro != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(viewModel.mensagemErro!)));
            });
          }

          if (viewModel.status == LoginStatus.sucesso) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const Home()),
              );
            });
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Informe o e-mail'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Informe a senha'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (viewModel.status == LoginStatus.erro &&
                      viewModel.mensagemErro != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        viewModel.mensagemErro!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: carregando
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              viewModel.entrar(
                                _emailController.text,
                                _senhaController.text,
                              );
                            }
                          },
                    child: carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
