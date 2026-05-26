import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soyyo/features/auth/domain/auth_service.dart';

// Fake mínimo para criar FirebaseAuthException sem Firebase inicializado
FirebaseAuthException _exc(String code, {String? message}) =>
    FirebaseAuthException(code: code, message: message);

void main() {
  group('AuthService.errorMessage', () {
    test('user-not-found', () {
      final msg = AuthService.errorMessage(_exc('user-not-found'));
      expect(msg, contains('e-mail'));
    });

    test('wrong-password retorna mensagem de credencial inválida', () {
      final msg = AuthService.errorMessage(_exc('wrong-password'));
      expect(msg.toLowerCase(), contains('senha'));
    });

    test('invalid-credential retorna mensagem de credencial inválida', () {
      final msg = AuthService.errorMessage(_exc('invalid-credential'));
      expect(msg.toLowerCase(), contains('senha'));
    });

    test('email-already-in-use', () {
      final msg = AuthService.errorMessage(_exc('email-already-in-use'));
      expect(msg.toLowerCase(), contains('e-mail'));
    });

    test('weak-password', () {
      final msg = AuthService.errorMessage(_exc('weak-password'));
      expect(msg.toLowerCase(), contains('senha'));
    });

    test('invalid-email', () {
      final msg = AuthService.errorMessage(_exc('invalid-email'));
      expect(msg.toLowerCase(), contains('e-mail'));
    });

    test('too-many-requests', () {
      final msg = AuthService.errorMessage(_exc('too-many-requests'));
      expect(msg.isNotEmpty, isTrue);
    });

    test('account-exists-with-different-credential', () {
      final msg = AuthService.errorMessage(
        _exc('account-exists-with-different-credential'),
      );
      expect(msg.isNotEmpty, isTrue);
    });

    test('código desconhecido usa message do exception', () {
      final msg = AuthService.errorMessage(
        _exc('unknown-code', message: 'Erro customizado'),
      );
      expect(msg, equals('Erro customizado'));
    });

    test('código desconhecido sem message usa fallback', () {
      final msg = AuthService.errorMessage(_exc('unknown-code'));
      expect(msg, equals('Erro de autenticação.'));
    });
  });
}
