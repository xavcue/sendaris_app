import 'package:flutter/material.dart';

import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';

/// Constructor del contenido privado de una cuenta.
///
/// Recibe exclusivamente el contexto y UID que el
/// controlador de selección ha autorizado.
typedef AccountPrivateContentBuilder = Widget Function(
  BuildContext context,
  FirebaseAccountSlot slot,
  String userId,
);

/// Punto de montaje exclusivo del contenido privado.
///
/// No realiza autenticación ni concede autorizaciones.
/// Únicamente observa al controlador de selección.
///
/// Garantías de presentación:
///
/// - Sin autorización, no construye contenido privado.
/// - Durante una verificación, mantiene el contenido oculto.
/// - Al bloquear, desmonta el contenido anterior.
/// - Al cambiar de cuenta, utiliza un árbol nuevo.
/// - Al regresar al mismo UID después de un bloqueo,
///   no reutiliza el estado privado anterior.
///
/// El constructor inactivo será conectado posteriormente
/// con el login original de Sendaris.
///
/// El propietario del controlador debe administrar
/// su ciclo de vida y ejecutar dispose().
final class AccountPrivateContentHost extends StatefulWidget {
  const AccountPrivateContentHost({
    required this.selection,
    required this.lockedBuilder,
    required this.privateBuilder,
    super.key,
  });

  final AccountSessionSelectionController selection;
  final WidgetBuilder lockedBuilder;
  final AccountPrivateContentBuilder privateBuilder;

  @override
  State<AccountPrivateContentHost> createState() =>
      _AccountPrivateContentHostState();
}

final class _AccountPrivateContentHostState
    extends State<AccountPrivateContentHost> {
  /// Identifica una generación de montaje.
  ///
  /// Se incrementa al recibir una revocación, incluso
  /// si Flutter todavía no ha dibujado el estado bloqueado.
  ///
  /// Esto impide reutilizar el State de A cuando ocurre
  /// una transición rápida A -> B -> A entre fotogramas.
  int _mountGeneration = 0;

  @override
  void initState() {
    super.initState();

    widget.selection.addListener(_handleSelectionChanged);
  }

  void _handleSelectionChanged() {
    if (!mounted) {
      return;
    }

    if (!widget.selection.value) {
      _mountGeneration++;
    }

    setState(() {});
  }

  @override
  void didUpdateWidget(covariant AccountPrivateContentHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.selection, widget.selection)) {
      oldWidget.selection.removeListener(_handleSelectionChanged);

      widget.selection.addListener(_handleSelectionChanged);

      // Una autorización perteneciente al controlador
      // anterior nunca puede reutilizar el mismo árbol.
      _mountGeneration++;
    }
  }

  @override
  void dispose() {
    widget.selection.removeListener(_handleSelectionChanged);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;

    // Consultar primero el permiso efectivo.
    //
    // Un UID almacenado o una sesión Firebase
    // autenticada no son suficientes para entrar.
    if (!selection.value) {
      return Builder(builder: widget.lockedBuilder);
    }

    final slot = selection.selectedSlot;
    final userId = selection.selectedUserId;

    if (slot == null ||
        userId == null ||
        userId.isEmpty ||
        userId.trim() != userId) {
      return Builder(builder: widget.lockedBuilder);
    }

    // La clave incluye la generación de autorización.
    //
    // Por tanto, regresar a la misma cuenta no recupera
    // automáticamente el State, el Router ni los
    // ViewModels de una sesión privada anterior.
    final mountKey = ValueKey<String>(
      'account-private-${slot.name}-$userId-$_mountGeneration',
    );

    return KeyedSubtree(
      key: mountKey,
      child: Builder(
        builder: (privateContext) {
          // Volver a comprobar el permiso inmediatamente
          // antes de construir el contenido privado.
          if (!selection.value ||
              selection.selectedSlot != slot ||
              selection.selectedUserId != userId) {
            return Builder(builder: widget.lockedBuilder);
          }

          return widget.privateBuilder(privateContext, slot, userId);
        },
      ),
    );
  }
}
