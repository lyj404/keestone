package com.keestone.keestone

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.hardware.biometrics.BiometricManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat

/**
 * Transparent activity shown when the user taps an authentication-protected
 * autofill dataset. Prompts for biometrics/device credential and, on success,
 * tells the autofill framework to retry the fill request — which the service
 * answers with the real credentials from the snapshot.
 *
 * No Keystore gate needed here: the BiometricPrompt itself is the user
 * presence check, and the retry request only serves the snapshot that was
 * written while the vault was unlocked in the app.
 */
class AutofillAuthActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val manager = getSystemService(BiometricManager::class.java)
        val authenticators = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        } else {
            0
        }
        val canAuth = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager?.canAuthenticate(authenticators)
        } else {
            @Suppress("DEPRECATION")
            manager?.canAuthenticate()
        }
        if (canAuth != BiometricManager.BIOMETRIC_SUCCESS) {
            Log.w(TAG, "biometric unavailable: $canAuth")
            finishCancelled()
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    setResult(Activity.RESULT_OK)
                    finish()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    Log.w(TAG, "biometric auth error $errorCode: $errString")
                    finishCancelled()
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.autofill_auth_title))
            .setSubtitle(getString(R.string.autofill_auth_subtitle))
            .setAllowedAuthenticators(
                BiometricPrompt.Authenticators.BIOMETRIC_WEAK or
                    BiometricPrompt.Authenticators.DEVICE_CREDENTIAL,
            )
            .build()
        prompt.authenticate(info)
    }

    private fun finishCancelled() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    companion object {
        private const val TAG = "KeeStoneAutofillAuth"

        /** PendingIntent handed to Dataset.Builder.setAuthentication. */
        fun authIntentSender(context: android.content.Context): PendingIntent =
            PendingIntent.getActivity(
                context,
                2001,
                Intent(context, AutofillAuthActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
    }
}
