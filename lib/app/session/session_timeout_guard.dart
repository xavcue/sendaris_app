import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'session_timeout_policy.dart';
import 'session_timeout_store.dart';

class SessionTimeoutGuard extends StatefulWidget {
  const SessionTimeoutGuard({
    required this.authRepository,
    required this.store,
    required this.child,
    this.initialRecord,
    this.clock,
    super.key,
  });

  final AuthRepository authRepository;
  final SessionTimeoutStore store;
  final SessionTimeoutRecord? initialRecord;
  final DateTime Function()? clock;
  final Widget child;

  @override
  State<SessionTimeoutGuard> createState() => _SessionTimeoutGuardState();
}

class _SessionTimeoutGuardState extends State<SessionTimeoutGuard>
    with WidgetsBindingObserver {
  static const _persistenceInterval = Duration(seconds: 30);

  StreamSubscription<bool>? _authSubscription;
  StreamSubscription<String?>? _identitySubscription;

  Timer? _timer;

  Future<void> _pendingWrite = Future<void>.value();

  SessionTimeoutRecord? _record;

  String? _observedUserId;

  DateTime? _lastPersistenceRequest;

  int _writeRevision = 0;

  bool _covered = false;
  bool _backgrounded = false;
  bool _expiring = false;
  bool _hasError = false;

  DateTime _now() => (widget.clock ?? DateTime.now)().toUtc();

  String? _currentUserId() {
    if (!widget.authRepository.isAuthenticated ||
        widget.authRepository is! AuthIdentityRepository) {
      return null;
    }

    final repository = widget.authRepository as AuthIdentityRepository;
    return repository.currentUserId;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _record = widget.initialRecord;
    _observedUserId = _currentUserId();

    _authSubscription = widget.authRepository.authStateChanges.listen(
      (_) => _synchronizeAuthentication(),
    );

    if (widget.authRepository is AuthIdentityRepository) {
      final identity = widget.authRepository as AuthIdentityRepository;

      _identitySubscription = identity.userIdChanges.listen(
        (_) => _synchronizeAuthentication(),
      );
    }

    if (_observedUserId != null) {
      _covered = true;

      final record = _record;

      if (record == null ||
          record.userId != _observedUserId ||
          record.isExpired(_now(), restoring: true)) {
        unawaited(_expire());
      } else {
        _record = record.activity(_now());
        _enqueueWrite(_record, unlockOnSuccess: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
    _writeRevision++;

    unawaited(_authSubscription?.cancel());
    unawaited(_identitySubscription?.cancel());

    super.dispose();
  }

  void _synchronizeAuthentication() {
    if (!mounted) {
      return;
    }

    final newUserId = _currentUserId();

    if (newUserId == _observedUserId) {
      return;
    }

    _observedUserId = newUserId;

    _timer?.cancel();
    _backgrounded = false;
    _expiring = false;
    _hasError = false;
    _lastPersistenceRequest = null;

    if (newUserId == null) {
      _record = null;

      setState(() {
        _covered = false;
      });

      _enqueueWrite(null);
      return;
    }

    // Toda autenticación nueva inicia su propia vigencia.
    // Incluso A -> B -> A crea una sesión temporal nueva.
    final now = _now();

    _record = SessionTimeoutRecord(
      userId: newUserId,
      startedAt: now,
      lastActivityAt: now,
    );

    setState(() {
      _covered = true;
    });

    _enqueueWrite(_record, unlockOnSuccess: true);
  }

  void _enqueueWrite(
    SessionTimeoutRecord? value, {
    bool unlockOnSuccess = false,
  }) {
    final revision = ++_writeRevision;
    final precedingWrite = _pendingWrite;

    _pendingWrite = () async {
      try {
        await precedingWrite;
      } catch (_) {
        // Una escritura anterior fallida no debe bloquear
        // permanentemente las escrituras posteriores.
      }

      if (revision != _writeRevision) {
        return;
      }

      try {
        if (value == null) {
          await widget.store.clear();
        } else {
          await widget.store.write(value);
        }

        if (!mounted || revision != _writeRevision) {
          return;
        }

        _lastPersistenceRequest = _now();

        if (unlockOnSuccess &&
            !_backgrounded &&
            value != null &&
            value.userId == _currentUserId()) {
          setState(() {
            _covered = false;
            _hasError = false;
          });

          _scheduleDeadline();
        }
      } catch (_) {
        if (!mounted || revision != _writeRevision) {
          return;
        }

        if (_currentUserId() != null) {
          _timer?.cancel();

          setState(() {
            _covered = true;
            _hasError = true;
          });
        }
      }
    }();
  }

  void _registerActivity() {
    final record = _record;

    if (_covered ||
        _backgrounded ||
        _expiring ||
        record == null ||
        record.userId != _currentUserId()) {
      return;
    }

    final now = _now();

    if (record.isExpired(now)) {
      unawaited(_expire());
      return;
    }

    _record = record.activity(now);
    _scheduleDeadline();

    final lastWrite = _lastPersistenceRequest;

    if (lastWrite == null ||
        now.difference(lastWrite) >= _persistenceInterval) {
      _lastPersistenceRequest = now;
      _enqueueWrite(_record);
    }
  }

  void _scheduleDeadline() {
    _timer?.cancel();

    final record = _record;

    if (_covered ||
        _backgrounded ||
        record == null ||
        record.userId != _currentUserId()) {
      return;
    }

    final now = _now();

    if (record.isExpired(now)) {
      unawaited(_expire());
      return;
    }

    final idleDeadline = record.lastActivityAt.add(
      SessionTimeoutPolicy.foregroundIdle,
    );

    final absoluteDeadline = record.startedAt.add(
      SessionTimeoutPolicy.absolute,
    );

    final deadline = idleDeadline.isBefore(absoluteDeadline)
        ? idleDeadline
        : absoluteDeadline;

    final remaining = deadline.difference(now);

    _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!mounted) {
        return;
      }

      final latest = _record;

      if (latest != null && latest.isExpired(_now())) {
        unawaited(_expire());
      } else {
        _scheduleDeadline();
      }
    });
  }

  Future<void> _expire() async {
    if (_expiring) {
      return;
    }

    final userId = _currentUserId();

    if (userId == null) {
      _synchronizeAuthentication();
      return;
    }

    _expiring = true;
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _covered = true;
        _hasError = false;
      });
    }

    try {
      // FirebaseAuthRepository comprueba la identidad
      // capturada antes de realizar el cierre.
      await widget.authRepository.signOut();

      if (!mounted) {
        return;
      }

      _synchronizeAuthentication();

      if (_currentUserId() == userId) {
        setState(() {
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (_currentUserId() == userId) {
        setState(() {
          _covered = true;
          _hasError = true;
        });
      } else {
        _synchronizeAuthentication();
      }
    } finally {
      _expiring = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _enterBackground();
    } else if (state == AppLifecycleState.resumed) {
      _resume();
    }
  }

  void _enterBackground() {
    if (_backgrounded) {
      return;
    }

    _backgrounded = true;
    _timer?.cancel();

    final record = _record;

    if (record == null || record.userId != _currentUserId()) {
      return;
    }

    setState(() {
      _covered = true;
    });

    _record = record.backgrounded(_now());
    _enqueueWrite(_record);
  }

  void _resume() {
    if (!_backgrounded) {
      return;
    }

    _backgrounded = false;

    final record = _record;

    if (record == null || record.userId != _currentUserId()) {
      _synchronizeAuthentication();
      return;
    }

    if (record.isExpired(_now())) {
      unawaited(_expire());
      return;
    }

    _record = record.activity(_now());
    _enqueueWrite(_record, unlockOnSuccess: true);
  }

  void _retry() {
    if (_expiring) {
      return;
    }

    final record = _record;

    if (record == null ||
        record.userId != _currentUserId() ||
        record.isExpired(_now(), restoring: _backgrounded)) {
      unawaited(_expire());
      return;
    }

    _enqueueWrite(record, unlockOnSuccess: !_backgrounded);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Este Stack está por encima de MaterialApp.
      //
      // Alignment.topLeft no depende de Directionality.
      // Evita el error "No Directionality widget found"
      // tanto en las pruebas como al iniciar Android.
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _registerActivity(),
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) {
                _registerActivity();
              }

              return KeyEventResult.ignored;
            },
            child: widget.child,
          ),
        ),
        if (_covered)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFFF5F7F8),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Material(
                  color: const Color(0xFFF5F7F8),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 42,
                            color: Color(0xFF345D66),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Protegiendo tu sesión',
                            key: Key('session-timeout-protection'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF263F46),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _hasError
                                ? 'No pudimos completar la comprobación '
                                      'de seguridad. Inténtalo nuevamente.'
                                : 'Comprobando la vigencia de tu acceso...',
                            textAlign: TextAlign.center,
                          ),
                          if (_hasError) ...[
                            const SizedBox(height: 18),
                            FilledButton(
                              key: const Key('session-timeout-retry'),
                              onPressed: _retry,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
