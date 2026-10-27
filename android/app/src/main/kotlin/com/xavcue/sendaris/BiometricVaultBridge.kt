
package com.xavcue.sendaris

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
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

internal class BiometricVaultBridge(
    private val activity: MainActivity
) : MethodChannel.MethodCallHandler {

    companion object {
        // Identificadores originales: no cambiar sin migracion.
        private const val KEY_ALIAS =
            "sendaris." + "auth" + "03.biometric.v1"

        private const val PREFS_NAME =
            "sendaris." + "auth" + "03.vault.v1"

        private const val PREF_UID = "uid"
        private const val PREF_IV = "iv"
        private const val PREF_CIPHERTEXT = "ciphertext"

        private const val TRANSFORMATION = "AES/GCM/NoPadding"
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
        DEACTIVATE,
        RECOVER_INVALIDATED
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

            "recoverInvalidated" -> {
                startInvalidatedRecovery(
                    uid = call.argument<String>("uid"),
                    result = result
                )
            }

            "checkInvalidated" -> {
                val expectedUid = call.argument<String>("uid")
                val state = try {
                    readBindingState()
                } catch (_: Exception) {
                    BindingState(STATUS_UNAVAILABLE)
                }

                result.success(
                    validUid(expectedUid) &&
                        pendingRequest == null &&
                        state.status == STATUS_ENABLED &&
                        state.uid == expectedUid &&
                        isPermanentlyInvalidated()
                )
            }

            // La API antigua sin autenticacion nunca borra datos.
            "clearBinding" -> {
                result.success(status(STATUS_DENIED))
            }

            else -> result.notImplemented()
        }
    }

    fun cancelPending() {
        val request = pendingRequest ?: return

        try {
            request.prompt.cancelAuthentication()
        } catch (_: Exception) {
            // La operacion se trata como cancelada.
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
                if (binding.status != STATUS_DISABLED) {
                    result.success(status(STATUS_DENIED))
                    return
                }
            }

            Operation.RECOVER_INVALIDATED -> {
                result.success(status(STATUS_DENIED))
                return
            }

            Operation.UNLOCK,
            Operation.DEACTIVATE -> {
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

                Operation.RECOVER_INVALIDATED ->
                    throw IllegalStateException("Operacion excepcional")
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

    /**
     * Solo reconoce invalidacion permanente del Keystore.
     * Fallos temporales, bloqueos o cancelaciones no autorizan
     * recuperar ni eliminar la vinculacion.
     */
    private fun isPermanentlyInvalidated(): Boolean {
        return try {
            createUnlockCipher()
            false
        } catch (error: Exception) {
            var cause: Throwable? = error
            var remaining = 8

            while (cause != null && remaining-- > 0) {
                if (cause is KeyPermanentlyInvalidatedException) {
                    return true
                }

                cause = cause.cause
            }

            false
        }
    }

    /**
     * Flutter debe haber reautenticado recientemente el mismo UID
     * mediante Firebase antes de solicitar esta operacion.
     * Android exige ademas PIN, patron o bloqueo del dispositivo.
     */
    private fun startInvalidatedRecovery(
        uid: String?,
        result: MethodChannel.Result
    ) {
        if (pendingRequest != null || !validUid(uid)) {
            result.success(status(STATUS_DENIED))
            return
        }

        val expectedUid = uid!!

        val binding = try {
            readBindingState()
        } catch (_: Exception) {
            BindingState(STATUS_UNAVAILABLE)
        }

        if (
            binding.status != STATUS_ENABLED ||
            binding.uid != expectedUid ||
            !isPermanentlyInvalidated() ||
            Build.VERSION.SDK_INT < Build.VERSION_CODES.R
        ) {
            result.success(status(STATUS_DENIED))
            return
        }

        lateinit var request: PendingRequest

        val callback =
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult
                ) {
                    if (pendingRequest !== request) {
                        return
                    }

                    val accepted = try {
                        val current = readBindingState()

                        current.status == STATUS_ENABLED &&
                            current.uid == expectedUid &&
                            isPermanentlyInvalidated() &&
                            clearStoredBinding()
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
                            errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                            errorCode == BiometricPrompt.ERROR_CANCELED

                    finish(
                        request,
                        if (cancelled) {
                            STATUS_CANCELLED
                        } else {
                            STATUS_UNAVAILABLE
                        }
                    )
                }
            }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            callback
        )

        val promptInfo = try {
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Recuperar acceso seguro")
                .setSubtitle("Confirma el bloqueo del dispositivo")
                .setAllowedAuthenticators(
                    BiometricManager.Authenticators.DEVICE_CREDENTIAL
                )
                .build()
        } catch (_: Exception) {
            result.success(status(STATUS_UNAVAILABLE))
            return
        }

        request = PendingRequest(
            operation = Operation.RECOVER_INVALIDATED,
            uid = expectedUid,
            result = result,
            prompt = prompt
        )

        pendingRequest = request

        try {
            // No se utiliza la antigua clave invalidada.
            prompt.authenticate(promptInfo)
        } catch (_: Exception) {
            finish(request, STATUS_UNAVAILABLE)
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

        val callback =
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authenticationResult: BiometricPrompt.AuthenticationResult
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

                            Operation.RECOVER_INVALIDATED -> false

                            Operation.DEACTIVATE -> {
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
                            errorCode == BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                            errorCode == BiometricPrompt.ERROR_CANCELED

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
                    // Una huella incorrecta no concede acceso.
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

            Operation.RECOVER_INVALIDATED ->
                "Confirma el bloqueo del dispositivo para recuperar el vinculo"
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

        val response =
            if (outcome == STATUS_VERIFIED) {
                mapOf(
                    "status" to STATUS_VERIFIED,
                    "uid" to request.uid
                )
            } else {
                status(outcome)
            }

        request.result.success(response)
    }

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
        val key =
            loadKey()
                ?: throw IllegalStateException("Clave inexistente")

        val encodedIv =
            preferences.getString(
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
        val encoded =
            preferences.getString(
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

    private fun readBindingState(): BindingState {
        val uid = preferences.getString(PREF_UID, null)
        val iv = preferences.getString(PREF_IV, null)
        val ciphertext =
            preferences.getString(PREF_CIPHERTEXT, null)

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