import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../widgets/sendaris_animated_launch.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';
import 'session_timeout_store.dart';

class SessionTimeoutGuard extends StatefulWidget {
  const SessionTimeoutGuard({
    required this.authRepository,
    required this.store,
    required this.child,
    this.initialRecord,
    this.clock,
    this.accessSelection,
    this.conventionalSlot,
    super.key,
  }) : assert(
         (accessSelection == null) == (conventionalSlot == null),
         'La seleccion y el slot convencional se requieren juntos.',
       );

  final AuthRepository authRepository;
  final SessionTimeoutStore store;
  final SessionTimeoutRecord? initialRecord;
  final DateTime Function()? clock;
  final AccountSessionSelectionController? accessSelection;
  final FirebaseAccountSlot? conventionalSlot;
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
  int _sourceRevision = 0;

  bool _covered = false;
  bool _backgrounded = false;
  bool _expiring = false;
  bool _hasError = false;

  DateTime _now() => (widget.clock ?? DateTime.now)().toUtc();

  /// El guard convencional sigue observando su repositorio aunque
  /// otra cuenta este seleccionada. Solo su interfaz y actividad
  /// se condicionan a la autorizacion privada correspondiente.
  bool _isConventionalContextSelected() {
    final selection = widget.accessSelection;
    final slot = widget.conventionalSlot;

    // Compatibilidad con el arranque sin dos contextos Firebase.
    if (selection == null || slot == null) {
      return true;
    }

    final userId = _currentUserId();

    return userId != null &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId;
  }

  /// Una superposicion visual no impide que el contenido situado
  /// debajo ejecute initState, cree ViewModels o realice lecturas.
  ///
  /// En el modo dual, el contenido convencional solo puede
  /// montarse despues de confirmar su vigencia temporal.
  ///
  /// El contexto biometrico y la interfaz sin seleccion privada
  /// conservan su arbol independientemente de este guard.
  bool _mustUnmountConventionalPrivateContent() {
    // El arranque convencional conserva su comportamiento anterior.
    if (widget.accessSelection == null || widget.conventionalSlot == null) {
      return false;
    }

    // Nunca ocultar A por una operacion pendiente de B.
    if (!_isConventionalContextSelected()) {
      return false;
    }

    final record = _record;
    final userId = _currentUserId();

    // Una cuenta convencional seleccionada no puede montar su
    // contenido mientras el registro temporal no sea valido.
    return _covered ||
        _backgrounded ||
        _expiring ||
        _hasError ||
        userId == null ||
        record == null ||
        record.userId != userId ||
        record.isExpired(_now());
  }

  /// Cuando B vuelve a seleccionarse, la vigencia debe
  /// comprobarse inmediatamente.
  ///
  /// No dependemos exclusivamente del Timer, porque puede
  /// haberse retrasado durante una suspension de la aplicacion.
  ///
  /// Diferimos la revocacion hasta que finalice la notificacion
  /// del selector. Durante ese intervalo el contenido privado
  /// vencido permanece desmontado por el control B4.
  void _onAccessSelectionChanged() {
    if (!mounted) {
      return;
    }

    final record = _record;
    final userId = _currentUserId();

    if (!_expiring &&
        _isConventionalContextSelected() &&
        record != null &&
        record.userId == userId &&
        record.isExpired(_now(), restoring: _backgrounded)) {
      final sourceRevision = _sourceRevision;

      scheduleMicrotask(() {
        if (!mounted ||
            sourceRevision != _sourceRevision ||
            _expiring ||
            _currentUserId() != userId) {
          return;
        }

        final currentRecord = _record;

        if (currentRecord == null ||
            currentRecord.userId != userId ||
            !currentRecord.isExpired(_now(), restoring: _backgrounded)) {
          return;
        }

        // El vencimiento pertenece a B, incluso si A
        // vuelve a seleccionarse antes de esta microtarea.
        //
        // Un cambio de UID o de repositorio, en cambio,
        // invalida la revocacion pendiente.
        unawaited(_expire());
      });
    }

    setState(() {});
  }

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
    widget.accessSelection?.addListener(_onAccessSelectionChanged);

    _record = widget.initialRecord;
    _observedUserId = _currentUserId();

    _listenToRepository();

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

  /// Permite cambiar el repositorio convencional
  /// vigilado sin desmontar el arbol hijo.
  ///
  /// La transicion debe haber sido autorizada
  /// previamente por el componente raiz.
  ///
  /// Nunca debe utilizarse como sustituto de
  /// la validacion de identidad Firebase.
  @override
  void didUpdateWidget(covariant SessionTimeoutGuard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.accessSelection, widget.accessSelection)) {
      oldWidget.accessSelection?.removeListener(_onAccessSelectionChanged);
      widget.accessSelection?.addListener(_onAccessSelectionChanged);
    }

    if (identical(oldWidget.authRepository, widget.authRepository) &&
        identical(oldWidget.store, widget.store)) {
      return;
    }

    // Invalidar callbacks y escrituras anteriores.
    _sourceRevision++;
    _writeRevision++;

    _timer?.cancel();

    unawaited(_authSubscription?.cancel());
    unawaited(_identitySubscription?.cancel());

    _authSubscription = null;
    _identitySubscription = null;

    _record = null;
    _observedUserId = null;
    _lastPersistenceRequest = null;

    _backgrounded = false;
    _expiring = false;
    _hasError = false;
    _covered = false;

    _listenToRepository();

    // Un cambio de contexto confirmado no es
    // una restauracion automatica de Firebase.
    //
    // Si existe una cuenta convencional en el
    // contexto nuevo, comienza una vigencia nueva
    // que debe persistirse antes de mostrarla.
    _synchronizeAuthentication();

    if (_observedUserId == null) {
      // El contexto nuevo esta vacio.
      // El registro del contexto anterior ya
      // no puede reutilizarse.
      _enqueueWrite(null);
    }
  }

  /// Cada escucha pertenece a una revision concreta.
  ///
  /// Los eventos tardios del repositorio anterior
  /// no pueden modificar la sesion actualmente vigilada.
  void _listenToRepository() {
    final revision = ++_sourceRevision;

    _authSubscription = widget.authRepository.authStateChanges.listen(
      (_) {
        if (mounted && revision == _sourceRevision) {
          _synchronizeAuthentication();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted && revision == _sourceRevision) {
          unawaited(_expire());
        }
      },
    );

    if (widget.authRepository is AuthIdentityRepository) {
      final identity = widget.authRepository as AuthIdentityRepository;

      _identitySubscription = identity.userIdChanges.listen(
        (_) {
          if (mounted && revision == _sourceRevision) {
            _synchronizeAuthentication();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mounted && revision == _sourceRevision) {
            unawaited(_expire());
          }
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.accessSelection?.removeListener(_onAccessSelectionChanged);

    _timer?.cancel();

    _writeRevision++;
    _sourceRevision++;

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

    // Toda autenticacion nueva inicia su propia
    // vigencia, incluso una transicion A -> B -> A.
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
        // Una escritura antigua fallida no debe
        // bloquear las escrituras posteriores.
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

    if (!_isConventionalContextSelected() ||
        _covered ||
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

    // Capturar el repositorio y su revision.
    //
    // Una respuesta antigua no debe cerrar el
    // repositorio que se selecciono posteriormente.
    final sourceRevision = _sourceRevision;
    final expiringRepository = widget.authRepository;

    _expiring = true;
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _covered = true;
        _hasError = false;
      });
    }

    try {
      if (sourceRevision != _sourceRevision ||
          !identical(expiringRepository, widget.authRepository) ||
          _currentUserId() != userId) {
        return;
      }

      // El repositorio Firebase comprueba ademas
      // la identidad capturada antes del cierre.
      await expiringRepository.signOut();

      if (!mounted || sourceRevision != _sourceRevision) {
        return;
      }

      _synchronizeAuthentication();

      if (_currentUserId() == userId) {
        setState(() {
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted || sourceRevision != _sourceRevision) {
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
      if (sourceRevision == _sourceRevision) {
        _expiring = false;
      }
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

    // La cuenta B conserva su marca de segundo plano
    // aunque A sea la cuenta privada seleccionada.
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

    final now = _now();

    // Comprobar primero el vencimiento de B
    // con su marca original de segundo plano.
    if (record.isExpired(now)) {
      unawaited(_expire());
      return;
    }

    if (!_isConventionalContextSelected()) {
      // El regreso con A no constituye actividad
      // autorizada de la cuenta convencional B.
      //
      // Conservar:
      // - Inicio absoluto de la sesion.
      // - Ultima actividad convencional real.
      //
      // Eliminar backgroundAt tras volver al primer plano.
      final resumedWithoutActivity = SessionTimeoutRecord(
        userId: record.userId,
        startedAt: record.startedAt,
        lastActivityAt: record.lastActivityAt,
      );

      // Al regresar al primer plano vuelve a aplicarse
      // el limite de inactividad convencional.
      if (resumedWithoutActivity.isExpired(now)) {
        unawaited(_expire());
        return;
      }

      _record = resumedWithoutActivity;

      // Confirmar la nueva marca temporal sin renovar
      // la actividad de B ni mostrar su overlay sobre A.
      _enqueueWrite(_record, unlockOnSuccess: true);

      return;
    }

    // B seleccionada: conservar la renovacion convencional
    // cuando su vigencia temporal todavia es valida.
    _record = record.activity(now);

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
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _registerActivity();
          },
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) {
                _registerActivity();
              }

              return KeyEventResult.ignored;
            },

            // En modo dual, mientras B carezca de una vigencia
            // confirmada no se monta ningun widget privado de B.
            //
            // Ocultarlo con el overlay no seria suficiente.
            // A y la interfaz de acceso sin seleccion siguen vivas.
            child: _mustUnmountConventionalPrivateContent()
                ? const SizedBox.expand()
                : widget.child,
          ),
        ),

        if (_covered && _isConventionalContextSelected())
          Positioned.fill(
            child: _hasError
                ? ColoredBox(
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
                                  'No se pudo confirmar tu sesión',
                                  key: Key('session-timeout-protection'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF263F46),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No pudimos completar la comprobación de '
                                  'seguridad. Inténtalo nuevamente.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 18),
                                FilledButton(
                                  key: const Key('session-timeout-retry'),
                                  onPressed: _retry,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                // El contenido privado de B permanece desmontado.
                // Durante una comprobacion normal, continuar con la
                // marca visual de arranque sin otra pantalla textual.
                // Sin una segunda animacion no se programan frames
                // innecesarios mientras se confirma la escritura.
                : const TickerMode(
                    enabled: false,
                    child: SendarisAnimatedLaunch(
                      key: Key('session-timeout-protection'),
                    ),
                  ),
          ),
      ],
    );
  }
}
