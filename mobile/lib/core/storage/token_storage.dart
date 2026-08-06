import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstração de armazenamento do token JWT — injetável/mockável para testes.
abstract class TokenStorage {
  Future<void> salvar(String token);
  Future<String?> ler();
  Future<void> limpar();
}

/// Implementação padrão de [TokenStorage], persistindo com
/// [FlutterSecureStorage] sob a chave `jwt_token`.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _chave = 'jwt_token';

  final FlutterSecureStorage _storage;

  @override
  Future<void> salvar(String token) => _storage.write(key: _chave, value: token);

  @override
  Future<String?> ler() => _storage.read(key: _chave);

  @override
  Future<void> limpar() => _storage.delete(key: _chave);
}
