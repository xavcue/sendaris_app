package com.xavcue.sendaris

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Continuidad nativa independiente del almacen
 * biometrico original de Sendaris.
 *
 * Mantiene las operaciones existentes:
 * - activate: emision mediante su propio BiometricPrompt.
 * - verify: comprobacion criptografica sin nuevo dialogo.
 * - revoke: eliminacion de la credencial.
 *
 * Nueva operacion:
 * - activateAfterUnlock: emision tras un desbloqueo
 *   criptografico original confirmado.
 *
 * La nueva operacion no muestra otro BiometricPrompt.
 * Requiere una autorizacion de un solo uso producida
 * por MainActivity tras un resultado original VERIFIED.
 *
 * Este servicio no concede acceso Firebase o Firestore.
 */
internal class LinkedContinuityBridge(
    private val activity: MainActivity
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val KEY_ALIAS =
            "sendaris.auth03.continuity.v1"

        private const val PREFS_NAME =
            "sendaris.auth03.continuity.proof.v1"

        private const val PREF_UID = "uid"
        private const val PREF_SLOT = "slot"
        private const val PREF_IV = "iv"
        private const val PREF_CIPHERTEXT = "ciphertext"

        private const val BIOMETRIC_KEY_ALIAS =
            "sendaris.auth03.biometric.v1"

        private const val BIOMETRIC_PREFS_NAME =
            "sendaris.auth03.vault.v1"

        private const val TRANSFORMATION =
            "AES/GCM/NoPadding"

        private const val TAG_BITS = 128
        private const val IV_BYTES = 12
        private const val VERSION = 1

        private const val VALIDITY_SECONDS = 7200
        private const val VALIDITY_MILLIS = 7200000L

        // Plazo maximo entre verificar la huella
        // original y consumir su autorizacion.
        private const val UNLOCK_WINDOW_MILLIS = 120000L

        private const val STATUS_ACTIVATED = "activated"
        private const val STATUS_VERIFIED = "verified"
        private const val STATUS_REVOKED = "revoked"
        private const val STATUS_DENIED = "denied"
        private const val STATUS_CANCELLED = "cancelled"
        private const val STATUS_UNAVAILABLE = "unavailable"

        private const val AAD =
            "sendaris:linked-continuity:v1"
    }

    private data class SessionIdentity(
        val slot: String,
        val uid: String,
        val startedAtMs: Long
    )

    private data class PendingActivation(
        val identity: SessionIdentity,
        val result: MethodChannel.Result,
        val prompt: BiometricPrompt
    )

    private data class PendingVaultUnlock(
        val challengeId: Long,
        val uid: String,
        val createdAtElapsed: Long
    )

    private data class VerifiedVaultUnlock(
        val uid: String,
        val verifiedAtElapsed: Long
    )

    private val preferences by lazy {
        activity.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )
    }

    private var pendingActivation: PendingActivation? = null

    private var pendingVaultUnlock: PendingVaultUnlock? = null
    private var verifiedVaultUnlock: VerifiedVaultUnlock? = null
    private var nextChallengeId = 0L

    /**
     * Preparacion ANTES del dialogo biometrico original.
     *
     * La clave temporal debe existir cuando Android
     * complete la autenticacion fuerte del usuario.
     *
     * Un fallo aqui no modifica ni impide el
     * desbloqueo original de Sendaris.
     *
     * El challengeId permanece solo en Kotlin.
     */
    fun prepareForVaultUnlock(uid: String?): Long? {
        pendingVaultUnlock = null
        verifiedVaultUnlock = null

        if (!validUid(uid) ||
            !nativeSupported() ||
            !deviceUnlocked() ||
            !matchingBiometricBinding(uid!!)
        ) {
            return null
        }

        return try {
            // Nunca modifica la clave biometrica
            // original ni los datos de la cuenta.
            loadOrCreateKey()

            nextChallengeId++

            val challenge = PendingVaultUnlock(
                challengeId = nextChallengeId,
                uid = uid,
                createdAtElapsed = SystemClock.elapsedRealtime()
            )

            pendingVaultUnlock = challenge
            challenge.challengeId
        } catch (_: Exception) {
            pendingVaultUnlock = null
            null
        }
    }

    /**
     * MainActivity invoca esta funcion solamente
     * cuando termina la llamada original del vault.
     *
     * VERIFIED debe provenir del descifrado real
     * de BiometricVaultBridge, no de Flutter.
     *
     * Ninguna credencial se emite aqui.
     */
    fun finishVaultUnlock(
        challengeId: Long?,
        uid: String?,
        verified: Boolean
    ) {
        val pending = pendingVaultUnlock
        pendingVaultUnlock = null

        if (pending == null ||
            challengeId == null ||
            !verified ||
            pending.challengeId != challengeId ||
            pending.uid != uid
        ) {
            return
        }

        val elapsed =
            SystemClock.elapsedRealtime() -
                pending.createdAtElapsed

        if (elapsed < 0L ||
            elapsed > UNLOCK_WINDOW_MILLIS
        ) {
            return
        }

        verifiedVaultUnlock = VerifiedVaultUnlock(
            uid = pending.uid,
            verifiedAtElapsed = SystemClock.elapsedRealtime()
        )
    }

    /**
     * Borra cualquier autorizacion aun no consumida.
     *
     * No revoca una credencial de continuidad ya
     * emitida: esa tarea corresponde a revoke().
     */
    fun clearUnlockEvidence() {
        pendingVaultUnlock = null
        verifiedVaultUnlock = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "activate" -> {
                val identity = readIdentity(call)

                if (identity == null) {
                    result.success(status(STATUS_DENIED))
                } else {
                    activate(identity, result)
                }
            }

            "activateAfterUnlock" -> {
                val identity = readIdentity(call)

                if (identity == null) {
                    result.success(status(STATUS_DENIED))
                } else {
                    result.success(
                        activateAfterUnlock(identity)
                    )
                }
            }

            "verify" -> {
                val identity = readIdentity(call)

                if (identity == null) {
                    result.success(status(STATUS_DENIED))
                } else {
                    result.success(verify(identity))
                }
            }

            "revoke" -> {
                val slot = call.argument<String>("slot")
                val uid = call.argument<String>("uid")

                if (!validSlot(slot) || !validUid(uid)) {
                    result.success(status(STATUS_DENIED))
                } else {
                    result.success(revoke(slot!!, uid!!))
                }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Consume una sola vez la autorizacion derivada
     * del desbloqueo biometrico original.
     *
     * No puede activarse solo por tener una sesion
     * Firebase o una fecha guardada en preferencias.
     *
     * MainActivity debe haber confirmado antes
     * el resultado criptografico del vault original.
     */
    private fun activateAfterUnlock(
        identity: SessionIdentity
    ): Map<String, Any> {
        val evidence = verifiedVaultUnlock

        // Consumir ANTES de intentar cualquier
        // operacion criptografica o escritura.
        verifiedVaultUnlock = null

        if (pendingActivation != null ||
            pendingVaultUnlock != null ||
            evidence == null ||
            evidence.uid != identity.uid ||
            !deviceUnlocked() ||
            !matchingBiometricBinding(identity.uid)
        ) {
            return status(STATUS_DENIED)
        }

        val elapsed =
            SystemClock.elapsedRealtime() -
                evidence.verifiedAtElapsed

        if (elapsed < 0L ||
            elapsed > UNLOCK_WINDOW_MILLIS
        ) {
            return status(STATUS_DENIED)
        }

        val accepted = try {
            saveAuthorizedProof(identity)
        } catch (_: Exception) {
            false
        }

        return if (accepted) {
            identityResponse(
                status = STATUS_ACTIVATED,
                identity = identity
            )
        } else {
            status(STATUS_DENIED)
        }
    }

    fun cancelPending() {
        clearUnlockEvidence()

        val request = pendingActivation ?: return

        try {
            request.prompt.cancelAuthentication()
        } catch (_: Exception) {
            // La operacion se invalida igualmente.
        }

        finishActivation(
            request,
            STATUS_CANCELLED
        )
    }

    private fun readIdentity(
        call: MethodCall
    ): SessionIdentity? {
        val slot = call.argument<String>("slot")
        val uid = call.argument<String>("uid")

        val startedAtMs = call.argument<Number>(
            "startedAtMs"
        )?.toLong()

        if (!validSlot(slot) ||
            !validUid(uid) ||
            startedAtMs == null ||
            startedAtMs <= 0L ||
            startedAtMs > System.currentTimeMillis()
        ) {
            return null
        }

        return SessionIdentity(
            slot = slot!!,
            uid = uid!!,
            startedAtMs = startedAtMs
        )
    }

    private fun validSlot(
        slot: String?
    ): Boolean {
        return slot == "primary" ||
            slot == "secondary"
    }

    private fun validUid(
        uid: String?
    ): Boolean {
        return uid != null &&
            uid.isNotEmpty() &&
            uid.length <= 256 &&
            uid.trim() == uid &&
            uid.none {
                Character.isISOControl(it)
            }
    }

    private fun nativeSupported(): Boolean {
        return Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.R
    }

    private fun strongBiometricsAvailable(): Boolean {
        if (!nativeSupported()) {
            return false
        }

        return try {
            BiometricManager.from(
                activity
            ).canAuthenticate(
                BiometricManager.Authenticators.BIOMETRIC_STRONG
            ) == BiometricManager.BIOMETRIC_SUCCESS
        } catch (_: Exception) {
            false
        }
    }

    private fun deviceUnlocked(): Boolean {
        return try {
            val manager = activity.getSystemService(
                Context.KEYGUARD_SERVICE
            ) as? KeyguardManager

            manager != null &&
                !manager.isDeviceLocked
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Comprueba que la vinculacion original sigue
     * asociada al UID y que su clave no esta invalidada.
     *
     * No realiza doFinal y no pide otra huella.
     */
    private fun matchingBiometricBinding(
        uid: String
    ): Boolean {
        return try {
            val original = activity.getSharedPreferences(
                BIOMETRIC_PREFS_NAME,
                Context.MODE_PRIVATE
            )

            val registeredUid = original.getString(
                PREF_UID,
                null
            )

            val encodedIv = original.getString(
                PREF_IV,
                null
            )

            val encodedCiphertext = original.getString(
                PREF_CIPHERTEXT,
                null
            )

            if (registeredUid != uid ||
                encodedIv.isNullOrEmpty() ||
                encodedCiphertext.isNullOrEmpty()
            ) {
                return false
            }

            val iv = Base64.decode(
                encodedIv,
                Base64.NO_WRAP
            )

            if (iv.size != IV_BYTES) {
                return false
            }

            val ciphertext = Base64.decode(
                encodedCiphertext,
                Base64.NO_WRAP
            )

            if (ciphertext.size < TAG_BITS / 8) {
                return false
            }

            val originalKey = keyStore().getKey(
                BIOMETRIC_KEY_ALIAS,
                null
            ) as? SecretKey ?: return false

            val cipher = Cipher.getInstance(
                TRANSFORMATION
            )

            cipher.init(
                Cipher.DECRYPT_MODE,
                originalKey,
                GCMParameterSpec(
                    TAG_BITS,
                    iv
                )
            )

            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Operacion original de activacion que presenta
     * su propio dialogo biometrico.
     *
     * Se conserva para las pruebas anteriores.
     */
    private fun activate(
        identity: SessionIdentity,
        result: MethodChannel.Result
    ) {
        if (pendingActivation != null) {
            result.success(status(STATUS_DENIED))
            return
        }

        if (!strongBiometricsAvailable() ||
            !deviceUnlocked() ||
            !matchingBiometricBinding(identity.uid)
        ) {
            result.success(status(STATUS_UNAVAILABLE))
            return
        }

        lateinit var request: PendingActivation

        val callback =
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    authenticationResult:
                        BiometricPrompt.AuthenticationResult
                ) {
                    if (pendingActivation !== request) {
                        return
                    }

                    val accepted = try {
                        deviceUnlocked() &&
                            matchingBiometricBinding(
                                request.identity.uid
                            ) &&
                            saveAuthorizedProof(
                                request.identity
                            )
                    } catch (_: Exception) {
                        false
                    }

                    finishActivation(
                        request,
                        if (accepted) {
                            STATUS_ACTIVATED
                        } else {
                            STATUS_DENIED
                        }
                    )
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    if (pendingActivation !== request) {
                        return
                    }

                    val cancelled =
                        errorCode ==
                            BiometricPrompt.ERROR_USER_CANCELED ||
                        errorCode ==
                            BiometricPrompt.ERROR_NEGATIVE_BUTTON ||
                        errorCode ==
                            BiometricPrompt.ERROR_CANCELED

                    finishActivation(
                        request,
                        if (cancelled) {
                            STATUS_CANCELLED
                        } else {
                            STATUS_UNAVAILABLE
                        }
                    )
                }

                override fun onAuthenticationFailed() {
                    // No se emite una credencial.
                }
            }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            callback
        )

        val promptInfo =
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Seguridad de Sendaris")
                .setSubtitle(
                    "Confirma tu identidad para " +
                        "mantener el acceso seguro"
                )
                .setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_STRONG
                )
                .setConfirmationRequired(true)
                .setNegativeButtonText("Cancelar")
                .build()

        request = PendingActivation(
            identity = identity,
            result = result,
            prompt = prompt
        )

        pendingActivation = request

        try {
            prompt.authenticate(promptInfo)
        } catch (_: Exception) {
            finishActivation(
                request,
                STATUS_UNAVAILABLE
            )
        }
    }

    private fun finishActivation(
        request: PendingActivation,
        outcome: String
    ) {
        if (pendingActivation !== request) {
            return
        }

        pendingActivation = null

        request.result.success(
            if (outcome == STATUS_ACTIVATED) {
                identityResponse(
                    status = STATUS_ACTIVATED,
                    identity = request.identity
                )
            } else {
                status(outcome)
            }
        )
    }

    /**
     * Clave independiente autorizada temporalmente.
     *
     * La autorizacion nativa dura como maximo
     * 7200 segundos y no se renueva por la actividad
     * de Flutter.
     */
    private fun loadOrCreateKey(): SecretKey {
        val existing = keyStore().getKey(
            KEY_ALIAS,
            null
        ) as? SecretKey

        if (existing != null) {
            return existing
        }

        val specification =
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or
                    KeyProperties.PURPOSE_DECRYPT
            )
                .setKeySize(256)
                .setBlockModes(
                    KeyProperties.BLOCK_MODE_GCM
                )
                .setEncryptionPaddings(
                    KeyProperties.ENCRYPTION_PADDING_NONE
                )
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(
                    VALIDITY_SECONDS,
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                )
                .build()

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )

        generator.init(specification)

        return generator.generateKey()
    }

    private fun saveAuthorizedProof(
        identity: SessionIdentity
    ): Boolean {
        val issuedAtMs = System.currentTimeMillis()

        if (issuedAtMs < identity.startedAtMs) {
            return false
        }

        val key = loadOrCreateKey()

        val payload = JSONObject()
            .put("version", VERSION)
            .put("slot", identity.slot)
            .put("uid", identity.uid)
            .put(
                "startedAtMs",
                identity.startedAtMs
            )
            .put(
                "issuedAtMs",
                issuedAtMs
            )
            .toString()
            .toByteArray(Charsets.UTF_8)

        val cipher = Cipher.getInstance(
            TRANSFORMATION
        )

        cipher.init(
            Cipher.ENCRYPT_MODE,
            key
        )

        cipher.updateAAD(
            AAD.toByteArray(Charsets.UTF_8)
        )

        val encrypted = cipher.doFinal(payload)
        val iv = cipher.iv ?: return false

        if (iv.size != IV_BYTES) {
            return false
        }

        return preferences.edit()
            .putString(
                PREF_UID,
                identity.uid
            )
            .putString(
                PREF_SLOT,
                identity.slot
            )
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

    private fun verify(
        identity: SessionIdentity
    ): Map<String, Any> {
        if (pendingActivation != null ||
            !nativeSupported() ||
            !deviceUnlocked() ||
            !matchingBiometricBinding(identity.uid)
        ) {
            return status(STATUS_DENIED)
        }

        val accepted = try {
            verifyStoredProof(identity)
        } catch (_: Exception) {
            false
        }

        return if (accepted) {
            identityResponse(
                status = STATUS_VERIFIED,
                identity = identity
            )
        } else {
            status(STATUS_DENIED)
        }
    }

    private fun verifyStoredProof(
        identity: SessionIdentity
    ): Boolean {
        val savedUid = preferences.getString(
            PREF_UID,
            null
        )

        val savedSlot = preferences.getString(
            PREF_SLOT,
            null
        )

        if (savedUid != identity.uid ||
            savedSlot != identity.slot
        ) {
            return false
        }

        val ivEncoded = preferences.getString(
            PREF_IV,
            null
        ) ?: return false

        val ciphertextEncoded = preferences.getString(
            PREF_CIPHERTEXT,
            null
        ) ?: return false

        val iv = Base64.decode(
            ivEncoded,
            Base64.NO_WRAP
        )

        if (iv.size != IV_BYTES) {
            return false
        }

        val encrypted = Base64.decode(
            ciphertextEncoded,
            Base64.NO_WRAP
        )

        val key = keyStore().getKey(
            KEY_ALIAS,
            null
        ) as? SecretKey ?: return false

        val cipher = Cipher.getInstance(
            TRANSFORMATION
        )

        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(
                TAG_BITS,
                iv
            )
        )

        cipher.updateAAD(
            AAD.toByteArray(Charsets.UTF_8)
        )

        val decrypted = cipher.doFinal(encrypted)

        val payload = JSONObject(
            String(
                decrypted,
                Charsets.UTF_8
            )
        )

        if (payload.optInt("version") != VERSION ||
            payload.optString("slot") != identity.slot ||
            payload.optString("uid") != identity.uid ||
            payload.optLong("startedAtMs") !=
                identity.startedAtMs
        ) {
            return false
        }

        val issuedAtMs = payload.optLong(
            "issuedAtMs",
            -1L
        )

        val now = System.currentTimeMillis()

        if (issuedAtMs <= 0L ||
            issuedAtMs < identity.startedAtMs ||
            now < issuedAtMs
        ) {
            return false
        }

        return now - issuedAtMs < VALIDITY_MILLIS
    }

    private fun revoke(
        slot: String,
        uid: String
    ): Map<String, Any> {
        // El cierre debe impedir reutilizar una
        // autorizacion temporal aun no consumida.
        clearUnlockEvidence()

        val pending = pendingActivation

        if (pending != null) {
            if (pending.identity.slot != slot ||
                pending.identity.uid != uid
            ) {
                return status(STATUS_DENIED)
            }

            cancelPending()
        }

        val storedUid = preferences.getString(
            PREF_UID,
            null
        )

        val storedSlot = preferences.getString(
            PREF_SLOT,
            null
        )

        if ((storedUid != null && storedUid != uid) ||
            (storedSlot != null && storedSlot != slot)
        ) {
            return status(STATUS_DENIED)
        }

        return try {
            val storage = keyStore()

            if (storage.containsAlias(KEY_ALIAS)) {
                storage.deleteEntry(KEY_ALIAS)
            }

            val committed = preferences.edit()
                .remove(PREF_UID)
                .remove(PREF_SLOT)
                .remove(PREF_IV)
                .remove(PREF_CIPHERTEXT)
                .commit()

            if (committed &&
                !storage.containsAlias(KEY_ALIAS)
            ) {
                mapOf(
                    "status" to STATUS_REVOKED,
                    "slot" to slot,
                    "uid" to uid
                )
            } else {
                status(STATUS_DENIED)
            }
        } catch (_: Exception) {
            status(STATUS_UNAVAILABLE)
        }
    }

    private fun keyStore(): KeyStore {
        return KeyStore.getInstance(
            "AndroidKeyStore"
        ).apply {
            load(null)
        }
    }

    private fun status(
        value: String
    ): Map<String, Any> {
        return mapOf("status" to value)
    }

    private fun identityResponse(
        status: String,
        identity: SessionIdentity
    ): Map<String, Any> {
        return mapOf(
            "status" to status,
            "slot" to identity.slot,
            "uid" to identity.uid,
            "startedAtMs" to identity.startedAtMs
        )
    }
}