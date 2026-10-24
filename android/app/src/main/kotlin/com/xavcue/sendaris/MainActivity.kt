package com.xavcue.sendaris

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Actividad principal de Sendaris.
 *
 * Mantiene independientes:
 * - La verificacion biometrica original.
 * - La credencial de continuidad vinculada.
 * - La sincronizacion de apariencia nativa.
 *
 * No contiene herramientas temporales de diagnostico.
 */
class MainActivity : FlutterFragmentActivity() {

    private var biometricVault: BiometricVaultBridge? = null
    private var linkedContinuity: LinkedContinuityBridge? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        val vault = BiometricVaultBridge(this)
        biometricVault = vault

        val continuity = LinkedContinuityBridge(this)
        linkedContinuity = continuity

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xavcue.sendaris/biometric_vault"
        ).setMethodCallHandler { call, result ->
            handleBiometricVaultCall(
                vault = vault,
                continuity = continuity,
                call = call,
                result = result
            )
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xavcue.sendaris/linked_continuity"
        ).setMethodCallHandler(continuity)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xavcue.sendaris/appearance"
        ).setMethodCallHandler { call, result ->
            handleAppearanceCall(
                call = call,
                result = result
            )
        }
    }

    /**
     * Sincroniza la apariencia nativa con la seleccion
     * almacenada por Flutter.
     *
     * En Android 12+ utiliza el modo propio de la
     * aplicacion mediante UiModeManager.
     *
     * En Android anterior a API 31, Flutter conserva
     * el control de Claro, Oscuro y Sistema.
     *
     * No modifica el modo global del dispositivo.
     */
    private fun handleAppearanceCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        if (call.method != "setMode") {
            result.notImplemented()
            return
        }

        val requestedMode = call.argument<String>("mode")

        if (
            requestedMode != "light" &&
            requestedMode != "dark" &&
            requestedMode != "system"
        ) {
            result.error(
                "invalid_appearance_mode",
                "Modo de apariencia no reconocido.",
                null
            )
            return
        }

        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                result.success(false)
                return
            }

            val manager = getSystemService(
                Context.UI_MODE_SERVICE
            ) as? UiModeManager

            if (manager == null) {
                result.error(
                    "appearance_unavailable",
                    "El servicio de apariencia no esta disponible.",
                    null
                )
                return
            }

            val nativeMode = when (requestedMode) {
                "light" -> UiModeManager.MODE_NIGHT_NO
                "dark" -> UiModeManager.MODE_NIGHT_YES
                else -> UiModeManager.MODE_NIGHT_AUTO
            }

            manager.setApplicationNightMode(nativeMode)

            result.success(true)
        } catch (_: Exception) {
            result.error(
                "appearance_unavailable",
                "No se pudo sincronizar la apariencia.",
                null
            )
        }
    }

    /**
     * Conserva el desbloqueo criptografico original.
     *
     * Solamente una respuesta VERIFIED de
     * BiometricVaultBridge puede confirmar la
     * autorizacion temporal de continuidad.
     *
     * La autorizacion temporal no constituye por
     * si sola una sesion valida en Firebase.
     */
    private fun handleBiometricVaultCall(
        vault: BiometricVaultBridge,
        continuity: LinkedContinuityBridge,
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        if (call.method != "unlock") {
            vault.onMethodCall(call, result)
            return
        }

        val expectedUid = call.argument<String>("uid")

        // Preparar la autorizacion temporal antes
        // del BiometricPrompt original.
        val challengeId = continuity.prepareForVaultUnlock(
            expectedUid
        )

        val forwardedResult = object : MethodChannel.Result {

            override fun success(value: Any?) {
                val original = value as? Map<*, *>

                val verified =
                    original?.get("status") == "verified" &&
                        expectedUid != null &&
                        original["uid"] == expectedUid

                // Confirmar solo cuando el vault original
                // verifico correctamente el mismo UID.
                continuity.finishVaultUnlock(
                    challengeId = challengeId,
                    uid = expectedUid,
                    verified = verified
                )

                // Devolver exactamente la respuesta
                // original, sin campos de diagnostico.
                result.success(value)
            }

            override fun error(
                errorCode: String,
                errorMessage: String?,
                errorDetails: Any?
            ) {
                continuity.finishVaultUnlock(
                    challengeId = challengeId,
                    uid = expectedUid,
                    verified = false
                )

                result.error(
                    errorCode,
                    errorMessage,
                    errorDetails
                )
            }

            override fun notImplemented() {
                continuity.finishVaultUnlock(
                    challengeId = challengeId,
                    uid = expectedUid,
                    verified = false
                )

                result.notImplemented()
            }
        }

        try {
            vault.onMethodCall(
                call,
                forwardedResult
            )
        } catch (_: Exception) {
            continuity.finishVaultUnlock(
                challengeId = challengeId,
                uid = expectedUid,
                verified = false
            )

            result.success(
                mapOf(
                    "status" to "unavailable"
                )
            )
        }
    }

    override fun onDestroy() {
        linkedContinuity?.cancelPending()
        linkedContinuity = null

        biometricVault?.cancelPending()
        biometricVault = null

        super.onDestroy()
    }
}