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

  /// Entra via [viewModel] e, depois do `await`, navega para [Home] em
  /// caso de sucesso ou mostra o erro num SnackBar. Rodar isso aqui — e não
  /// dentro do `builder` do `Consumer` — evita que um rebuild qualquer (ex.:
  /// girar o aparelho) reexiba o SnackBar de uma tentativa antiga.
  Future<void> _entrar(BuildContext context, LoginViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final sucesso = await viewModel.entrar(
      _emailController.text,
      _senhaController.text,
    );
    if (!context.mounted) return;

    if (sucesso) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const Home()));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(viewModel.mensagemErro ?? 'Erro ao entrar')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Consumer<LoginViewModel>(
        builder: (context, viewModel, child) {
          final carregando = viewModel.status == LoginStatus.carregando;

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
                        : () => _entrar(context, viewModel),
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
