
package com.xavcue.sendaris

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Almacen biometrico nativo de Sendaris.
 *
 * Vincula una identidad Firebase con una clave AES de
 * Android Keystore. Cada operacion sensible requiere
 * autenticacion biometrica fuerte y un CryptoObject.
 *
 * Este servicio no concede acceso a Firebase ni a
 * datos privados. La autorizacion de la aplicacion
 * se verifica de manera independiente en Flutter.
 */
internal class BiometricVaultBridge(
    private val activity: MainActivity
) : MethodChannel.MethodCallHandler {

    companion object {
        /*
         * Identificadores persistentes existentes.
         *
         * Se conservan exactamente sus valores para
         * no invalidar las vinculaciones anteriores.
         *
         * No renombrar ni borrar estas claves sin una
         * migracion de almacenamiento comprobada.
         */
        private const val KEY_ALIAS =
            "sendaris." + "auth" + "03.biometric.v1"

        private const val PREFS_NAME =
            "sendaris." + "auth" + "03.vault.v1"

        private const val PREF_UID = "uid"
        private const val PREF_IV = "iv"
        private const val PREF_CIPHERTEXT = "ciphertext"

        private const val TRANSFORMATION =
            "AES/GCM/NoPadding"

        private const val TAG_BITS = 128
        private const val IV_BYTES = 12

        private const val STATUS_DISABLED = "disabled"
        private const val STATUS_ENABLED = "enabled"
        private const val STATUS_VERIFIED = "verified"
        private const val STATUS_DENIED = "denied"
        private const val STATUS_CANCELLED = "cancelled"
        private const val STATUS_UNAVAILABLE = "unavailable"
    }

    private enum class Operation {
        ENROLL,
        UNLOCK,
        DEACTIVATE
    }

    private data class BindingState(
        val status: String,
        val uid: String? = null
    ) {
        fun response(): Map<String, String> {
            return if (uid == null) {
                mapOf("status" to status)
            } else {
                mapOf(
                    "status" to status,
                    "uid" to uid
                )
            }
        }
    }

    private data class PendingRequest(
        val operation: Operation,
        val uid: String,
        val result: MethodChannel.Result,
        val prompt: BiometricPrompt
    )

    private val preferences by lazy {
        activity.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
    }

    private var pendingRequest: PendingRequest? = null

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "readBinding" -> {
                val state = try {
                    if (pendingRequest != null) {
                        BindingState(STATUS_UNAVAILABLE)
                    } else {
                        readBindingState()
                    }
                } catch (_: Exception) {
                    BindingState(STATUS_UNAVAILABLE)
                }

                result.success(state.response())
            }

            "enroll" -> {
                startOperation(
                    operation = Operation.ENROLL,
                    uid = call.argument<String>("uid"),
                    result = result
                )
            }

            "unlock" -> {
                startOperation(
                    operation = Operation.UNLOCK,
                    uid = call.argument<String>("uid"),
                    result = result
                )
            }

            "deactivate" -> {
                startOperation(
                    operation = Operation.DEACTIVATE,
                    uid = call.argument<String>("uid"),
                    result = result
                )
            }

            /*
             * API antigua sin autenticacion.
             *
             * Nunca debe borrar una vinculacion.
             * La unica desvinculacion permitida
             * requiere BiometricPrompt en deactivate.
             */
            "clearBinding" -> {
                result.success(status(STATUS_DENIED))
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Cancela la operacion nativa pendiente cuando
     * Android destruye la actividad.
     */
    fun cancelPending() {
        val request = pendingRequest ?: return

        try {
            request.prompt.cancelAuthentication()
        } catch (_: Exception) {
            // La operacion se tratara como cancelada.
        }

        finish(request, STATUS_CANCELLED)
    }

    private fun startOperation(
        operation: Operation,
        uid: String?,
        result: MethodChannel.Result
    ) {
        if (pendingRequest != null || !validUid(uid)) {
            result.success(status(STATUS_DENIED))
            return
        }

        val expectedUid = uid!!

        if (!strongBiometricsAvailable()) {
            result.success(status(STATUS_UNAVAILABLE))
            return
        }

        val binding = try {
            readBindingState()
        } catch (_: Exception) {
            BindingState(STATUS_UNAVAILABLE)
        }

        when (operation) {
            Operation.ENROLL -> {
                // No reemplazar vinculaciones existentes.
                if (binding.status != STATUS_DISABLED) {
                    result.success(status(STATUS_DENIED))
                    return
                }
            }

            Operation.UNLOCK,
            Operation.DEACTIVATE -> {
                // La clave de A nunca puede utilizarse
                // para autorizar operaciones de B.
                if (
                    binding.status != STATUS_ENABLED ||
                    binding.uid != expectedUid
                ) {
                    result.success(status(STATUS_DENIED))
                    return
                }
            }
        }

        try {
            val cipher = when (operation) {
                Operation.ENROLL -> createEnrollmentCipher()

                Operation.UNLOCK,
                Operation.DEACTIVATE -> createUnlockCipher()
            }

            showPrompt(
                operation = operation,
                uid = expectedUid,
                cipher = cipher,
                result = result
            )
        } catch (_: Exception) {
            if (operation == Operation.ENROLL) {
                discardUncommittedEnrollment()
            }

            result.success(status(STATUS_UNAVAILABLE))
        }
    }

    private fun strongBiometricsAvailable(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                false
            } else {
                BiometricManager.from(activity).canAuthenticate(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG
                ) == BiometricManager.BIOMETRIC_SUCCESS
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun showPrompt(
        operation: Operation,
        uid: String,
        cipher: Cipher,
        result: MethodChannel.Result
    ) {
        lateinit var request: PendingRequest

        val callback = object :
            BiometricPrompt.AuthenticationCallback() {

            override fun onAuthenticationSucceeded(
                authenticationResult:
                    BiometricPrompt.AuthenticationResult
            ) {
                if (pendingRequest !== request) {
                    return
                }

                val authenticatedCipher =
                    authenticationResult.cryptoObject?.cipher

                if (authenticatedCipher == null) {
                    finish(request, STATUS_DENIED)
                    return
                }

                val accepted = try {
                    when (operation) {
                        Operation.ENROLL -> {
                            completeEnrollment(
                                uid,
                                authenticatedCipher
                            )
                        }

                        Operation.UNLOCK -> {
                            completeUnlock(
                                uid,
                                authenticatedCipher
                            )
                        }

                        Operation.DEACTIVATE -> {
                            // La huella debe haber autorizado
                            // el descifrado de la vinculacion.
                            //
                            // Solo despues puede eliminarse
                            // la clave de Android Keystore.
                            completeUnlock(
                                uid,
                                authenticatedCipher
                            ) &&
                                readBindingState().let { state ->
                                    state.status == STATUS_ENABLED &&
                                        state.uid == uid
                                } &&
                                clearStoredBinding()
                        }
                    }
                } catch (_: Exception) {
                    false
                }

                finish(
                    request,
                    if (accepted) {
                        STATUS_VERIFIED
                    } else {
                        STATUS_DENIED
                    }
                )
            }

            override fun onAuthenticationError(
                errorCode: Int,
                errString: CharSequence
            ) {
                if (pendingRequest !== request) {
                    return
                }

                val cancelled =
                    errorCode == BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode ==
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                        errorCode ==
                            BiometricPrompt.ERROR_CANCELED

                finish(
                    request,
                    if (cancelled) {
                        STATUS_CANCELLED
                    } else {
                        STATUS_UNAVAILABLE
                    }
                )
            }

            override fun onAuthenticationFailed() {
                // Una huella incorrecta nunca concede
                // acceso ni elimina una vinculacion.
            }
        }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            callback
        )

        val subtitle = when (operation) {
            Operation.ENROLL ->
                "Confirma tu identidad para activar el acceso seguro"

            Operation.UNLOCK ->
                "Confirma tu identidad para desbloquear Sendaris"

            Operation.DEACTIVATE ->
                "Confirma tu identidad para desactivar el acceso seguro"
        }

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Seguridad de Sendaris")
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            )
            .setConfirmationRequired(true)
            .setNegativeButtonText("Cancelar")
            .build()

        request = PendingRequest(
            operation = operation,
            uid = uid,
            result = result,
            prompt = prompt
        )

        pendingRequest = request

        try {
            prompt.authenticate(
                promptInfo,
                BiometricPrompt.CryptoObject(cipher)
            )
        } catch (_: Exception) {
            finish(request, STATUS_UNAVAILABLE)
        }
    }

    private fun finish(
        request: PendingRequest,
        outcome: String
    ) {
        // Una respuesta antigua no completa
        // un desafio biometrico posterior.
        if (pendingRequest !== request) {
            return
        }

        pendingRequest = null

        if (
            request.operation == Operation.ENROLL &&
            outcome != STATUS_VERIFIED
        ) {
            discardUncommittedEnrollment()
        }

        val response = if (outcome == STATUS_VERIFIED) {
            mapOf(
                "status" to STATUS_VERIFIED,
                "uid" to request.uid
            )
        } else {
            status(outcome)
        }

        request.result.success(response)
    }

    /**
     * Crea la clave biometrica y prepara el cifrado.
     *
     * La clave se invalida ante cambios de enrolamiento
     * biometrico, segun las garantias de Android.
     */
    private fun createEnrollmentCipher(): Cipher {
        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or
                KeyProperties.PURPOSE_DECRYPT
        )
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(
                KeyProperties.ENCRYPTION_PADDING_NONE
            )
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG
            )
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )

        generator.init(builder.build())

        val key = generator.generateKey()

        return Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, key)
        }
    }

    private fun createUnlockCipher(): Cipher {
        val key = loadKey()
            ?: throw IllegalStateException("Clave inexistente")

        val encodedIv = preferences.getString(
            PREF_IV,
            null
        ) ?: throw IllegalStateException("IV inexistente")

        val iv = Base64.decode(
            encodedIv,
            Base64.NO_WRAP
        )

        require(iv.size == IV_BYTES)

        return Cipher.getInstance(TRANSFORMATION).apply {
            init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(TAG_BITS, iv)
            )
        }
    }

    private fun completeEnrollment(
        uid: String,
        cipher: Cipher
    ): Boolean {
        cipher.updateAAD(associatedData(uid))

        val encrypted = cipher.doFinal(
            protectedValue(uid)
        )

        val iv = cipher.iv ?: return false

        if (iv.size != IV_BYTES) {
            return false
        }

        return preferences.edit()
            .putString(PREF_UID, uid)
            .putString(
                PREF_IV,
                Base64.encodeToString(
                    iv,
                    Base64.NO_WRAP
                )
            )
            .putString(
                PREF_CIPHERTEXT,
                Base64.encodeToString(
                    encrypted,
                    Base64.NO_WRAP
                )
            )
            .commit()
    }

    private fun completeUnlock(
        uid: String,
        cipher: Cipher
    ): Boolean {
        val encoded = preferences.getString(
            PREF_CIPHERTEXT,
            null
        ) ?: return false

        val encrypted = Base64.decode(
            encoded,
            Base64.NO_WRAP
        )

        cipher.updateAAD(associatedData(uid))

        val decrypted = cipher.doFinal(encrypted)

        return decrypted.contentEquals(
            protectedValue(uid)
        )
    }

    /**
     * Devuelve informacion estructural.
     *
     * Leer el UID no equivale a autenticarlo:
     * la prueba criptografica sucede con la huella.
     */
    private fun readBindingState(): BindingState {
        val uid = preferences.getString(PREF_UID, null)
        val iv = preferences.getString(PREF_IV, null)

        val ciphertext = preferences.getString(
            PREF_CIPHERTEXT,
            null
        )

        val hasKey = keyStore().containsAlias(KEY_ALIAS)

        if (
            uid == null &&
            iv == null &&
            ciphertext == null &&
            !hasKey
        ) {
            return BindingState(STATUS_DISABLED)
        }

        if (
            !validUid(uid) ||
            iv.isNullOrEmpty() ||
            ciphertext.isNullOrEmpty() ||
            !hasKey
        ) {
            return BindingState(STATUS_UNAVAILABLE)
        }

        val decodedIv = try {
            Base64.decode(iv, Base64.NO_WRAP)
        } catch (_: Exception) {
            return BindingState(STATUS_UNAVAILABLE)
        }

        if (decodedIv.size != IV_BYTES) {
            return BindingState(STATUS_UNAVAILABLE)
        }

        return BindingState(
            STATUS_ENABLED,
            uid
        )
    }

    /**
     * Eliminacion interna.
     *
     * No se expone directamente a Flutter.
     *
     * Se utiliza despues de autenticar deactivate
     * o para descartar una activacion inconclusa.
     */
    private fun clearStoredBinding(): Boolean {
        return try {
            val store = keyStore()

            if (store.containsAlias(KEY_ALIAS)) {
                store.deleteEntry(KEY_ALIAS)
            }

            val committed = preferences.edit()
                .remove(PREF_UID)
                .remove(PREF_IV)
                .remove(PREF_CIPHERTEXT)
                .commit()

            committed &&
                readBindingState().status == STATUS_DISABLED
        } catch (_: Exception) {
            false
        }
    }

    private fun discardUncommittedEnrollment() {
        // Solo se ejecuta cuando la activacion comenzo
        // sobre un almacen previamente desactivado.
        clearStoredBinding()
    }

    private fun loadKey(): SecretKey? {
        return keyStore().getKey(
            KEY_ALIAS,
            null
        ) as? SecretKey
    }

    private fun keyStore(): KeyStore {
        return KeyStore.getInstance(
            "AndroidKeyStore"
        ).apply {
            load(null)
        }
    }

    private fun protectedValue(uid: String): ByteArray {
        // Mantener el valor criptografico existente.
        return ("SENDARIS_AUTH" + "03_V1:$uid")
            .toByteArray(Charsets.UTF_8)
    }

    private fun associatedData(uid: String): ByteArray {
        return "sendaris:biometric-binding:v1:$uid"
            .toByteArray(Charsets.UTF_8)
    }

    private fun validUid(value: String?): Boolean {
        return value != null &&
            value.isNotEmpty() &&
            value.trim() == value
    }

    private fun status(value: String): Map<String, String> {
        return mapOf("status" to value)
    }
}
