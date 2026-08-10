import 'package:flutter/foundation.dart';

/// Base para os `ChangeNotifier`s de tela do app.
///
/// Um ViewModel é descartado pelo provider quando o widget que o escopa sai
/// da árvore: os das abas vivem no `Home` e caem no logout
/// (`pushReplacement`) ou na expiração de sessão (`onSessaoExpirada` em
/// `main.dart` faz `pushAndRemoveUntil`, derrubando a árvore inteira); o do
/// checkout é escopado à própria tela e cai a cada `pop`. Em qualquer um
/// desses casos uma requisição em voo continua rodando e, ao completar,
/// tenta gravar estado e notificar. `ChangeNotifier.notifyListeners()` tem
/// `assert(debugAssertNotDisposed(this))`, então isso lança
/// `FlutterError: A XViewModel was used after being disposed` em debug (em
/// release o assert é no-op, mas o VM já descartado seguir gravando estado
/// que ninguém mais lê continua sendo trabalho desperdiçado).
///
/// [notificarSeAtivo] substitui `notifyListeners()` nesses VMs: vira no-op
/// depois de [dispose].
abstract class BaseViewModel extends ChangeNotifier {
  bool _descartado = false;

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
