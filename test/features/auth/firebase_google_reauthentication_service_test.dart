import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/domain/repositories/google_identity_token_provider.dart';

void main() {
  late _FakeFirebaseAuth firebase;
  late _FakeGoogleTokenProvider google;
  late FirebaseAuthService service;

  setUp(() {
    firebase = _FakeFirebaseAuth();
    google = _FakeGoogleTokenProvider();

    service = FirebaseAuthService(
      firebase,
      googleIdentityTokenProvider: google,
    );
  });

  tearDown(() async {
    await firebase.dispose();
  });

  test('reautentica la misma cuenta Google', () async {
    firebase.setUser('uid-a');
    google.token = 'token-ficticio';

    final result = await service.reauthenticateCurrentUserWithGoogle();

    expect(result, isTrue);
    expect(firebase.currentUser?.uid, 'uid-a');
    expect(firebase.reauthenticationCalls, 1);
    expect(firebase.refreshTokenCalls, 1);
    expect(firebase.lastForceRefresh, isTrue);
    expect(firebase.lastCredential?.providerId, 'google.com');
  });

  test('cancelar Google conserva la cuenta y no reautentica', () async {
    firebase.setUser('uid-a');
    google.token = null;

    final result = await service.reauthenticateCurrentUserWithGoogle();

    expect(result, isFalse);
    expect(firebase.currentUser?.uid, 'uid-a');
    expect(firebase.reauthenticationCalls, 0);
    expect(firebase.refreshTokenCalls, 0);
  });

  test('rechaza reautenticación sin sesión', () async {
    google.token = 'token-ficticio';

    await expectLater(
      service.reauthenticateCurrentUserWithGoogle(),
      throwsA(isA<StateError>()),
    );

    expect(google.calls, 0);
    expect(firebase.reauthenticationCalls, 0);
  });

  test('rechaza cuentas sin proveedor Google', () async {
    firebase.setUser('uid-a', googleEnabled: false);
    google.token = 'token-ficticio';

    await expectLater(
      service.reauthenticateCurrentUserWithGoogle(),
      throwsA(isA<StateError>()),
    );

    expect(google.calls, 0);
    expect(firebase.reauthenticationCalls, 0);
  });

  test('Firebase rechaza una credencial de otra cuenta', () async {
    firebase.setUser('uid-a');
    google.token = 'token-ficticio';

    firebase.reauthenticationError = FirebaseAuthException(
      code: 'user-mismatch',
    );

    await expectLater(
      service.reauthenticateCurrentUserWithGoogle(),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'código',
          'user-mismatch',
        ),
      ),
    );

    expect(firebase.currentUser?.uid, 'uid-a');
    expect(firebase.reauthenticationCalls, 1);
    expect(firebase.refreshTokenCalls, 0);
  });

  test('cambio de UID durante el selector invalida la operación', () async {
    firebase.setUser('uid-a');

    final completer = Completer<String?>();
    google.pendingToken = completer.future;

    final pending = service.reauthenticateCurrentUserWithGoogle();

    firebase.setUser('uid-b');
    completer.complete('token-obsoleto');

    await expectLater(pending, throwsA(isA<StateError>()));

    expect(firebase.currentUser?.uid, 'uid-b');
    expect(firebase.reauthenticationCalls, 0);
  });

  test('detecta cambio A-B-A durante la selección', () async {
    firebase.setUser('uid-a');

    final completer = Completer<String?>();
    google.pendingToken = completer.future;

    final pending = service.reauthenticateCurrentUserWithGoogle();

    firebase.setUser('uid-b');
    firebase.setUser('uid-a');

    completer.complete('token-obsoleto');

    await expectLater(pending, throwsA(isA<StateError>()));

    expect(firebase.currentUser?.uid, 'uid-a');
    expect(firebase.reauthenticationCalls, 0);
  });

  test('cambio de cuenta durante reautenticación invalida resultado', () async {
    firebase.setUser('uid-a');
    google.token = 'token-ficticio';

    firebase.changeUserDuringReauthentication = 'uid-b';

    await expectLater(
      service.reauthenticateCurrentUserWithGoogle(),
      throwsA(isA<StateError>()),
    );

    expect(firebase.currentUser?.uid, 'uid-b');
    expect(firebase.reauthenticationCalls, 1);
    expect(firebase.refreshTokenCalls, 0);
  });

  test('cierre de sesión espera a la reautenticación Google', () async {
    firebase.setUser('uid-a');

    final completer = Completer<String?>();
    google.pendingToken = completer.future;

    final pendingReauthentication = service
        .reauthenticateCurrentUserWithGoogle();

    final pendingSignOut = service.signOut();

    expect(firebase.signOutCalls, 0);

    completer.complete('token-ficticio');

    expect(await pendingReauthentication, isTrue);

    await pendingSignOut;

    expect(firebase.reauthenticationCalls, 1);
    expect(firebase.signOutCalls, 1);
    expect(firebase.currentUser, isNull);
  });
}

class _FakeGoogleTokenProvider implements GoogleIdentityTokenProvider {
  String? token;
  Future<String?>? pendingToken;

  int calls = 0;

  @override
  Future<String?> requestIdToken() async {
    calls++;

    final pending = pendingToken;

    if (pending != null) {
      return pending;
    }

    return token;
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  _FakeUser? _user;

  Object? reauthenticationError;
  String? changeUserDuringReauthentication;
  AuthCredential? lastCredential;

  int reauthenticationCalls = 0;
  int refreshTokenCalls = 0;
  int signOutCalls = 0;

  bool lastForceRefresh = false;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void setUser(String? uid, {bool googleEnabled = true}) {
    _user = uid == null
        ? null
        : _FakeUser(firebase: this, uid: uid, googleEnabled: googleEnabled);

    _changes.add(_user);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    setUser(null);
  }

  Future<void> dispose() => _changes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeUser implements User {
  _FakeUser({
    required this.firebase,
    required this.uid,
    required this.googleEnabled,
  });

  final _FakeFirebaseAuth firebase;
  final bool googleEnabled;

  @override
  final String uid;

  @override
  List<UserInfo> get providerData {
    return [_FakeUserInfo(googleEnabled ? 'google.com' : 'password')];
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    firebase.reauthenticationCalls++;
    firebase.lastCredential = credential;

    final error = firebase.reauthenticationError;

    if (error != null) {
      throw error;
    }

    final nextUser = firebase.changeUserDuringReauthentication;

    if (nextUser != null) {
      firebase.setUser(nextUser);
    }

    return _FakeUserCredential(this);
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    firebase.refreshTokenCalls++;
    firebase.lastForceRefresh = forceRefresh;

    return 'firebase-token-ficticio';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeUserCredential implements UserCredential {
  _FakeUserCredential(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
