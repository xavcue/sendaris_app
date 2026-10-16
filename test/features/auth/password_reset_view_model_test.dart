import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/password_reset_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/password_reset_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/password_reset_view_model.dart';

void main() {
  late _FakePasswordResetRepository repository;
  late PasswordResetViewModel viewModel;

  setUp(() {
    repository = _FakePasswordResetRepository();
    viewModel = PasswordResetViewModel(repository);
  });

  tearDown(() {
    viewModel.dispose();
  });

  test('rechaza un correo vacío', () async {
    final result = await viewModel.requestPasswordReset(email: '  ');

    expect(result, isFalse);
    expect(viewModel.errorMessage, 'Ingresa tu correo electrónico.');
    expect(repository.requestedEmails, isEmpty);
  });

  test('rechaza un correo inválido', () async {
    final result = await viewModel.requestPasswordReset(
      email: 'correo-invalido',
    );

    expect(result, isFalse);
    expect(viewModel.errorMessage, 'Ingresa un correo electrónico válido.');
    expect(repository.requestedEmails, isEmpty);
  });

  test('normaliza espacios y confirma la solicitud', () async {
    final result = await viewModel.requestPasswordReset(
      email: '  usuario@example.com  ',
    );

    expect(result, isTrue);
    expect(repository.requestedEmails, ['usuario@example.com']);
    expect(viewModel.isSent, isTrue);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('no vuelve a enviar después del éxito', () async {
    await viewModel.requestPasswordReset(email: 'usuario@example.com');

    final result = await viewModel.requestPasswordReset(
      email: 'usuario@example.com',
    );

    expect(result, isFalse);
    expect(repository.requestedEmails.length, 1);
  });

  test('impide solicitudes simultáneas', () async {
    final completer = Completer<void>();
    repository.pendingRequest = completer;

    final first = viewModel.requestPasswordReset(email: 'usuario@example.com');

    expect(viewModel.isLoading, isTrue);

    final second = await viewModel.requestPasswordReset(
      email: 'usuario@example.com',
    );

    expect(second, isFalse);
    expect(repository.requestedEmails.length, 1);

    completer.complete();

    expect(await first, isTrue);
    expect(viewModel.isLoading, isFalse);
  });

  test('presenta errores controlados del dominio', () async {
    repository.failure = const PasswordResetFailure(
      'Inténtalo nuevamente más tarde.',
    );

    final result = await viewModel.requestPasswordReset(
      email: 'usuario@example.com',
    );

    expect(result, isFalse);
    expect(viewModel.errorMessage, 'Inténtalo nuevamente más tarde.');
    expect(viewModel.isSent, isFalse);
    expect(viewModel.isLoading, isFalse);
  });

  test('oculta los errores técnicos inesperados', () async {
    repository.failure = StateError('Error interno que no debe mostrarse');

    final result = await viewModel.requestPasswordReset(
      email: 'usuario@example.com',
    );

    expect(result, isFalse);
    expect(
      viewModel.errorMessage,
      'No fue posible procesar la solicitud. '
      'Inténtalo nuevamente.',
    );
    expect(viewModel.errorMessage, isNot(contains('Error interno')));
  });

  test('permite limpiar el error al editar', () async {
    await viewModel.requestPasswordReset(email: '');

    expect(viewModel.errorMessage, isNotNull);

    viewModel.clearError();

    expect(viewModel.errorMessage, isNull);
  });
}

class _FakePasswordResetRepository implements PasswordResetRepository {
  final List<String> requestedEmails = [];

  Completer<void>? pendingRequest;
  Object? failure;

  @override
  Future<void> requestPasswordReset({required String email}) async {
    requestedEmails.add(email);

    final pending = pendingRequest;

    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      throw failure!;
    }
  }
}
