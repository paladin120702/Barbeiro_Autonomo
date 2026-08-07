import 'package:barbearia_app/core/base_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// VM mínimo só para exercitar o guard de [BaseViewModel] isoladamente,
/// sem depender de nenhum repository/mock de feature.
class _VmDeTeste extends BaseViewModel {
  int chamadas = 0;

  void notificar() {
    chamadas++;
    notificarSeAtivo();
  }

  bool get estaDescartado => descartado;
}

void main() {
  test(
    'notificarSeAtivo chama notifyListeners normalmente antes de dispose',
    () {
      final vm = _VmDeTeste();
      var notificacoes = 0;
      vm.addListener(() => notificacoes++);

      vm.notificar();

      expect(notificacoes, 1);
    },
  );

  test('notificarSeAtivo depois de dispose() não lança e não notifica '
      '(diferente de notifyListeners() puro, que lançaria FlutterError)', () {
    final vm = _VmDeTeste();
    var notificacoes = 0;
    vm.addListener(() => notificacoes++);

    vm.dispose();

    expect(() => vm.notificar(), returnsNormally);
    expect(notificacoes, 0);
    expect(vm.estaDescartado, isTrue);
  });
}
