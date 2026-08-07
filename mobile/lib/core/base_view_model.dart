import 'package:flutter/foundation.dart';

/// Base para os `ChangeNotifier`s de tela do app.
///
/// Cada `ChangeNotifierProvider` de feature cria seu ViewModel escopado à
/// tela (ex.: `TelaAgendaDoDia`, `TelaCaixa`); ao trocar de aba em `Home`
/// (que troca `body: _abas[_abaAtual]` em vez de manter as 4 abas montadas)
/// ou ao a sessão expirar (`onSessaoExpirada` em `main.dart` faz
/// `pushAndRemoveUntil`, derrubando a árvore inteira), o widget é
/// desmontado e o provider chama `dispose()` no ViewModel — mas uma
/// requisição em voo continua rodando e, ao completar, tenta gravar estado
/// e notificar. `ChangeNotifier.notifyListeners()` tem
/// `assert(debugAssertNotDisposed(this))`, então isso lança
/// `FlutterError: A XViewModel was used after being disposed` em debug (em
/// release o assert é no-op, mas o VM já descartado seguir gravando estado
/// que ninguém mais lê continua sendo trabalho desperdiçado).
///
/// [notificarSeAtivo] substitui `notifyListeners()` nesses VMs: vira no-op
/// depois de [dispose].
abstract class BaseViewModel extends ChangeNotifier {
  bool _descartado = false;

  /// Verdadeiro depois que [dispose] rodou. Útil em VMs que precisam checar
  /// antes de continuar um `await` (ex.: guard de sequenciamento).
  @protected
  bool get descartado => _descartado;

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }

  /// Notifica os listeners, exceto se este ViewModel já foi [dispose]d.
  @protected
  void notificarSeAtivo() {
    if (_descartado) return;
    notifyListeners();
  }
}
