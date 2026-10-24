import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de apariencia de Sendaris.
///
/// La seleccion pertenece al dispositivo, no a una cuenta.
///
/// Flutter utiliza esta preferencia para Inicio, Login
/// y la animacion de arranque.
///
/// Android recibe la misma seleccion para ajustar su
/// pantalla nativa de lanzamiento en dispositivos
/// compatibles.
///
/// No almacena informacion de autenticacion.
abstract final class SendarisThemePreference {
  static const String storageKey = 'sendaris.appearance.theme_mode.v1';

  static const MethodChannel _appearanceChannel = MethodChannel(
    'com.xavcue.sendaris/appearance',
  );

  static SharedPreferences? _preferences;
  static ThemeMode _selectedMode = ThemeMode.system;
  static bool _initialized = false;

  /// Serializa las escrituras para que un cambio anterior
  /// no termine despues del cambio mas reciente.
  static Future<void> _pendingWrite = Future<void>.value();

  static ThemeMode get selectedMode => _selectedMode;

  static bool get isInitialized => _initialized;

  /// Recupera la preferencia local antes de construir
  /// las pantallas Flutter.
  ///
  /// Tambien sincroniza el tema nativo. En Android 12+
  /// la preferencia nativa queda disponible para el
  /// siguiente lanzamiento del proceso.
  ///
  /// La ausencia de un canal nativo no impide iniciar
  /// Sendaris ni modifica las sesiones.
  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();

    _preferences = preferences;
    _selectedMode = parse(preferences.getString(storageKey));
    _initialized = true;

    await _synchronizeNative(_selectedMode);
  }

  static ThemeMode parse(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  /// Guarda la apariencia elegida desde Ajustes.
  ///
  /// El controlador Flutter refleja el cambio
  /// inmediatamente, mientras esta operacion actualiza
  /// el almacenamiento y el tema nativo.
  ///
  /// Devuelve true si SharedPreferences confirma
  /// el guardado local. La sincronizacion nativa es
  /// independiente y no bloquea el inicio de sesion.
  static Future<bool> save(ThemeMode mode) {
    _selectedMode = mode;

    final operation = _pendingWrite.then((_) async {
      try {
        final preferences =
            _preferences ?? await SharedPreferences.getInstance();

        _preferences = preferences;

        final saved = await preferences.setString(storageKey, mode.name);

        if (!saved) {
          return false;
        }

        await _synchronizeNative(mode);

        return true;
      } catch (_) {
        return false;
      }
    });

    // Una escritura fallida no impide guardar
    // posteriores cambios de apariencia.
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }

  /// Envia la seleccion a Android sin afectar la
  /// autenticacion o el almacenamiento Firebase.
  ///
  /// En pruebas Flutter o plataformas sin el canal,
  /// se conserva la apariencia gestionada por Flutter.
  static Future<void> _synchronizeNative(ThemeMode mode) async {
    try {
      await _appearanceChannel.invokeMethod<bool>('setMode', <String, String>{
        'mode': mode.name,
      });
    } on MissingPluginException {
      // No hay implementacion nativa en este entorno.
    } on PlatformException {
      // El modo Flutter sigue disponible.
    }
  }
}
