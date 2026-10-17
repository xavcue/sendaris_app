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

  test('autentica con Google y devuelve el UID de Firebase', () async {
    google.nextToken = 'token-google-ficticio';

    var started = false;

    final result = await service.signInWithGoogleObserved(
      onExecutionStarted: () {
        started = true;
      },
    );

    expect(started, isTrue);
    expect(result, 'uid-google');
    expect(firebase.currentUser?.uid, 'uid-google');
    expect(firebase.signInCalls, 1);
    expect(firebase.reloadCalls, 1);
    expect(firebase.refreshTokenCalls, 1);
    expect(firebase.lastForceRefresh, isTrue);
  });

  test('cancelar Google no modifica la sesión Firebase', () async {
    google.nextToken = null;

    final result = await service.signInWithGoogleObserved(
      onExecutionStarted: () {},
    );

    expect(result, isNull);
    expect(firebase.currentUser, isNull);
    expect(firebase.signInCalls, 0);
  });

  test('un error de Firebase se propaga sin cambiar la sesión', () async {
    google.nextToken = 'token-ficticio';
    firebase.signInFailure = FirebaseAuthException(
      code: 'account-exists-with-different-credential',
    );

    await expectLater(
      service.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<FirebaseAuthException>().having(
          (error) => error.code,
          'código',
          'account-exists-with-different-credential',
        ),
      ),
    );

    expect(firebase.signInCalls, 1);
    expect(firebase.currentUser, isNull);
  });

  test('un cambio de UID durante el selector impide autenticar', () async {
    final tokenPending = Completer<String?>();
    google.pendingToken = tokenPending.future;

    final pending = service.signInWithGoogleObserved(onExecutionStarted: () {});

    firebase.setUser('uid-otra-cuenta');

    tokenPending.complete('token-obsoleto');

    await expectLater(pending, throwsA(isA<StateError>()));

    expect(firebase.signInCalls, 0);
    expect(firebase.currentUser?.uid, 'uid-otra-cuenta');
  });

  test('detecta un cambio A a B a A durante el selector', () async {
    firebase.setUser('uid-a');

    final tokenPending = Completer<String?>();
    google.pendingToken = tokenPending.future;

    final pending = service.signInWithGoogleObserved(onExecutionStarted: () {});

    firebase.setUser('uid-b');
    firebase.setUser('uid-a');

    tokenPending.complete('token-obsoleto');

    await expectLater(pending, throwsA(isA<StateError>()));

    expect(firebase.signInCalls, 0);
    expect(firebase.currentUser?.uid, 'uid-a');
  });

  test('rechaza un cambio de identidad durante reload', () async {
    google.nextToken = 'token-google-ficticio';
    firebase.changeUserDuringReload = 'uid-otra-cuenta';

    await expectLater(
      service.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(isA<StateError>()),
    );

    expect(firebase.currentUser?.uid, 'uid-otra-cuenta');
    expect(firebase.refreshTokenCalls, 0);
  });

  test('una operación posterior espera a Google', () async {
    final tokenPending = Completer<String?>();
    google.pendingToken = tokenPending.future;

    final pendingGoogle = service.signInWithGoogleObserved(
      onExecutionStarted: () {},
    );

    final pendingSignOut = service.signOut();

    expect(firebase.signOutCalls, 0);

    tokenPending.complete(null);

    expect(await pendingGoogle, isNull);
    await pendingSignOut;

    expect(firebase.signOutCalls, 1);
    expect(firebase.currentUser, isNull);
  });

  test('un cierre en espera no desconecta otra identidad', () async {
    final tokenPending = Completer<String?>();
    google.pendingToken = tokenPending.future;

    final pendingGoogle = service.signInWithGoogleObserved(
      onExecutionStarted: () {},
    );

    final pendingSignOut = service.signOut();

    final signOutExpectation = expectLater(
      pendingSignOut,
      throwsA(isA<StateError>()),
    );

    tokenPending.complete('token-google-ficticio');

    expect(await pendingGoogle, 'uid-google');
    await signOutExpectation;

    expect(firebase.signOutCalls, 0);
    expect(firebase.currentUser?.uid, 'uid-google');
  });
}

class _FakeGoogleTokenProvider implements GoogleIdentityTokenProvider {
  String? nextToken;
  Future<String?>? pendingToken;

  @override
  Future<String?> requestIdToken() async {
    final pending = pendingToken;

    if (pending != null) {
      return pending;
    }

    return nextToken;
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  _FakeUser? _user;

  String nextSignInUserId = 'uid-google';
  String? changeUserDuringReload;

  Object? signInFailure;

  int signInCalls = 0;
  int signOutCalls = 0;
  int reloadCalls = 0;
  int refreshTokenCalls = 0;

  bool lastForceRefresh = false;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void setUser(String? uid) {
    _user = uid == null ? null : _FakeUser(this, uid);
    _changes.add(_user);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signInCalls++;

    final error = signInFailure;

    if (error != null) {
      throw error;
    }

    setUser(nextSignInUserId);

    return _FakeUserCredential(_user);
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
  _FakeUser(this._firebase, this.uid);

  final _FakeFirebaseAuth _firebase;

  @override
  final String uid;

  @override
  Future<void> reload() async {
    _firebase.reloadCalls++;

    final nextUser = _firebase.changeUserDuringReload;

    if (nextUser != null) {
      _firebase.setUser(nextUser);
    }
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    _firebase.refreshTokenCalls++;
    _firebase.lastForceRefresh = forceRefresh;

    return 'token-firebase-ficticio';
  }

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
