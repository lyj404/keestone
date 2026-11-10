package com.keestone.keestone

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.service.autofill.Dataset
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat

/**
 * Transparent activity shown when the user taps an authentication-protected
 * autofill dataset. Prompts for biometrics/device credential and, on success,
 * returns the selected, populated dataset to the autofill framework.
 *
 * No Keystore gate needed here: the BiometricPrompt itself is the user
 * presence check, and the result only serves the snapshot that was
 * written while the vault was unlocked in the app.
 */
class AutofillAuthActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val authenticators = BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL
        val manager = BiometricManager.from(this)
        val canAuth = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.canAuthenticate(authenticators)
        } else {
            @Suppress("DEPRECATION")
            manager.canAuthenticate()
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
                    finishAuthenticated()
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
            .setAllowedAuthenticators(authenticators)
            .build()
        prompt.authenticate(info)
    }

    private fun finishAuthenticated() {
        val packageId = intent.getStringExtra("packageId") ?: return finishCancelled()
        val uuid = intent.getStringExtra("uuid") ?: return finishCancelled()
        val candidate = KeeStoneAutofillService.AutofillSnapshotReader
            .query(this, packageId, intent.getStringExtra("domain"))
            .firstOrNull { it["uuid"] == uuid } ?: return finishCancelled()
        @Suppress("DEPRECATION")
        val usernames = intent.getParcelableArrayListExtra<AutofillId>("usernameIds").orEmpty()
        @Suppress("DEPRECATION")
        val passwords = intent.getParcelableArrayListExtra<AutofillId>("passwordIds").orEmpty()
        if (usernames.isEmpty() && passwords.isEmpty()) return finishCancelled()
        val view = RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, candidate["title"] as? String ?: "KeeStone")
        }
        val dataset = Dataset.Builder(view)
        usernames.forEach { dataset.setValue(it, AutofillValue.forText(candidate["username"] as? String ?: "")) }
        passwords.forEach { dataset.setValue(it, AutofillValue.forText(candidate["password"] as? String ?: "")) }
        setResult(Activity.RESULT_OK, Intent().putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, dataset.build()))
        finish()
    }

    private fun finishCancelled() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    companion object {
        private const val TAG = "KeeStoneAutofillAuth"

        /** PendingIntent handed to Dataset.Builder.setAuthentication. */
        fun authIntentSender(
            context: Context, requestCode: Int, packageId: String, domain: String?, uuid: String,
            usernameIds: List<AutofillId>, passwordIds: List<AutofillId>,
        ): PendingIntent =
            PendingIntent.getActivity(
                context,
                2001 + requestCode,
                Intent(context, AutofillAuthActivity::class.java).apply {
                    putExtra("packageId", packageId)
                    putExtra("domain", domain)
                    putExtra("uuid", uuid)
                    putParcelableArrayListExtra("usernameIds", ArrayList(usernameIds))
                    putParcelableArrayListExtra("passwordIds", ArrayList(passwordIds))
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
    }
}
