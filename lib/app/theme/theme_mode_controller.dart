import 'package:flutter/material.dart';

/// Controla la apariencia visible de Sendaris.
///
/// Conserva el comportamiento sincrono utilizado por
/// Inicio, Login y Ajustes.
///
/// El almacenamiento persistente se inyecta mediante
/// onChanged. Asi, las pruebas y otros consumidores
/// pueden utilizar el controlador sin depender de disco.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController({
    ThemeMode initialMode = ThemeMode.system,
    this.onChanged,
  }) : _themeMode = initialMode;

  ThemeMode _themeMode;

  /// Callback opcional para persistir la apariencia.
  ///
  /// El controlador no accede directamente al
  /// almacenamiento del dispositivo.
  final ValueChanged<ThemeMode>? onChanged;

  ThemeMode get themeMode => _themeMode;

  /// Cambia la apariencia de forma inmediata.
  ///
  /// Si el modo no ha cambiado, no realiza ninguna
  /// notificacion ni escritura innecesaria.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;

    // La aplicacion decide como almacenar la preferencia.
    // Cambiar la apariencia no debe bloquear la interfaz.
    onChanged?.call(mode);

    notifyListeners();
  }

  /// Alterna entre Claro y Oscuro tomando como
  /// referencia la apariencia efectiva actual.
  void toggle(Brightness currentBrightness) {
    setThemeMode(
      currentBrightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  /// Restablece la apariencia del dispositivo.
  void useSystemMode() {
    setThemeMode(ThemeMode.system);
  }
}
