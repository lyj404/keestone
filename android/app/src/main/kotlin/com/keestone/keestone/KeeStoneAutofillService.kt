package com.keestone.keestone

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch

private const val TAG = "KeeStoneAutofill"
private const val CHANNEL = "com.keestone.keestone/autofill"
private const val CHANNEL_TIMEOUT_MS = 4000L
private const val MAX_DATASETS = 10
private const val SNAPSHOT_NAME = "keestone_autofill_snapshot.bin"
private const val KEY_NAME = "keestone_autofill_snapshot.key"
// FillRequest.FLAG_AUTHENTICATION_RESULT (API 34+; constant value 4).
private const val FILL_FLAG_AUTHENTICATION_RESULT = 0x4

@RequiresApi(Build.VERSION_CODES.O)
class KeeStoneAutofillService : AutofillService() {

    private data class AutofillTarget(
        val packageName: String,
        val domain: String?,
        val usernameIds: List<AutofillId>,
        val passwordIds: List<AutofillId>,
    )

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        val structures = request.fillContexts.map { it.structure }
        val target = structures.firstNotNullOfOrNull { parseStructure(it) }
        if (target == null) {
            callback.onSuccess(null)
            return
        }

        // Primary path: decrypt the snapshot directly. OEM process managers
        // (e.g. OPPO HansManager) freeze background apps within seconds, so
        // the Dart engine usually cannot answer the channel in time.
        val candidates = querySnapshot(target.packageName, target.domain)
        if (candidates.isNotEmpty()) {
            val isAuthResult =
                (request.flags and FILL_FLAG_AUTHENTICATION_RESULT) != 0
            val response =
                if (isAuthResult) {
                    // User just authenticated via AutofillAuthActivity — fill now.
                    buildDatasetsResponse(target, candidates)
                } else {
                    // First pass: require biometric/device-credential confirmation
                    // before handing out credentials (Bitwarden-style flow).
                    buildBiometricGatedResponse(target, candidates)
                }
            callback.onSuccess(response ?: buildOpenAppResponse(target))
            return
        }
        if (snapshotExists()) {
            // Snapshot present but nothing matched this app/domain.
            callback.onSuccess(null)
            return
        }

        // Fallback: ask the live engine (also covers "vault open but no
        // snapshot yet"); on timeout offer to open the app.
        val result = queryEngine(target.packageName, target.domain)
        if (result == null) {
            callback.onSuccess(buildOpenAppResponse(target))
            return
        }

        when (result.getString("status")) {
            "unlocked" -> {
                @Suppress("UNCHECKED_CAST")
                val engineCandidates =
                    (result.get("candidates") as? List<Map<String, Any?>>) ?: emptyList()
                if (engineCandidates.isEmpty()) {
                    callback.onSuccess(null)
                } else {
                    buildDatasetsResponse(target, engineCandidates)?.let { callback.onSuccess(it) }
                        ?: callback.onSuccess(null)
                }
            }
            "locked" -> callback.onSuccess(buildUnlockResponse(target, result.getString("filePath")))
            else -> callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // KeeStone is read-only for autofill; never auto-save through the service.
        callback.onSuccess()
    }

    // ── Parsing ────────────────────────────────────────────────────────────────

    private fun parseStructure(
        structure: android.app.assist.AssistStructure,
    ): AutofillTarget? {
        val packageName = structure.activityComponent?.packageName ?: return null
        val usernameIds = mutableListOf<AutofillId>()
        val passwordIds = mutableListOf<AutofillId>()
        var domain: String? = null

        for (i in 0 until structure.windowNodeCount) {
            val window = structure.getWindowNodeAt(i)
            walkNode(window.rootViewNode, usernameIds, passwordIds) { d ->
                if (domain == null) domain = d
            }
        }
        if (usernameIds.isEmpty() && passwordIds.isEmpty()) return null
        return AutofillTarget(packageName, domain, usernameIds, passwordIds)
    }

    private fun walkNode(
        node: android.app.assist.AssistStructure.ViewNode,
        usernameIds: MutableList<AutofillId>,
        passwordIds: MutableList<AutofillId>,
        onDomain: (String) -> Unit,
    ) {
        // WebView domain: ViewNode.getWebDomain() (API 26+).
        val d = node.webDomain
        if (!d.isNullOrEmpty()) onDomain(d)
        val html = node.htmlInfo
        if (html != null) {
            var inputType = ""
            var action: String? = null
            for (entry in html.attributes.orEmpty()) {
                when (entry.first.lowercase()) {
                    "type" -> inputType = entry.second.lowercase()
                    "action", "href" -> if (action == null) action = entry.second
                }
            }
            action?.let { extractHost(it)?.let(onDomain) }
            when (html.tag.lowercase()) {
                "input" -> when (inputType) {
                    "password" -> node.autofillId?.let(passwordIds::add)
                    "email", "text", "tel", "username" ->
                        node.autofillId?.let(usernameIds::add)
                }
                "form" -> action?.let { extractHost(it)?.let(onDomain) }
            }
        } else {
            val hints = node.autofillHints?.toList().orEmpty()
            if (hints.any {
                    it == android.view.View.AUTOFILL_HINT_USERNAME ||
                        it == "username" ||
                        it == android.view.View.AUTOFILL_HINT_EMAIL_ADDRESS
                }) {
                node.autofillId?.let(usernameIds::add)
            }
            if (hints.any { it == android.view.View.AUTOFILL_HINT_PASSWORD }) {
                node.autofillId?.let(passwordIds::add)
            }
        }

        for (i in 0 until node.childCount) {
            walkNode(node.getChildAt(i), usernameIds, passwordIds, onDomain)
        }
    }

    private fun extractHost(url: String): String? = try {
        val u = java.net.URI(url)
        if (!u.host.isNullOrEmpty()) u.host else null
    } catch (_: Exception) {
        null
    }

    // ── Snapshot (no Dart involvement) ────────────────────────────────────────

    /**
     * Decrypts and matches the snapshot file written by Dart on unlock.
     * Same process/uid as the app, so the app-private files dir is readable
     * even while the Dart engine is frozen by OEM process managers.
     */
    private fun querySnapshot(packageId: String, domain: String?): List<Map<String, Any?>> {
        val snapshotFile = java.io.File(filesDir, SNAPSHOT_NAME)
        if (!snapshotFile.exists()) return emptyList()
        val keyFile = java.io.File(filesDir, KEY_NAME)
        if (!keyFile.exists()) return emptyList()
        return try {
            val bytes = snapshotFile.readBytes()
            if (bytes.size < 5 + 12 + 16 ||
                !(bytes[0] == 'K'.code.toByte() && bytes[1] == 'V'.code.toByte() &&
                    bytes[2] == 'A'.code.toByte() && bytes[3] == 'F'.code.toByte())
            ) {
                return emptyList()
            }
            val key = keyFile.readBytes()
            if (key.size != 32) return emptyList()
            val combined = bytes.copyOfRange(5, bytes.size)
            val secretKey = javax.crypto.spec.SecretKeySpec(key, "AES")
            val cipher = javax.crypto.Cipher.getInstance("AES/GCM/NoPadding")
            // GCM spec parameter: nonce(12) prefix + 128-bit tag appended.
            val spec = javax.crypto.spec.GCMParameterSpec(128, combined, 0, 12)
            cipher.init(javax.crypto.Cipher.DECRYPT_MODE, secretKey, spec)
            val clear = cipher.doFinal(combined, 12, combined.size - 12)
            val json = org.json.JSONObject(String(clear, Charsets.UTF_8))
            val entries = json.optJSONArray("entries") ?: return emptyList()
            val lowerPackage = packageId.lowercase()
            val lowerDomain = domain?.lowercase()
            data class Scored(val entry: org.json.JSONObject, val score: Int)
            val scored = mutableListOf<Scored>()
            for (i in 0 until entries.length()) {
                val e = entries.optJSONObject(i) ?: continue
                var best = 0
                val pkgs = e.optJSONArray("packageIds")
                if (pkgs != null) {
                    for (j in 0 until pkgs.length()) {
                        val pkg = pkgs.optString(j).lowercase()
                        when {
                            pkg == lowerPackage -> best = maxOf(best, 100)
                            lowerPackage.endsWith(".$pkg") ||
                                pkg.endsWith(".$lowerPackage") -> best = maxOf(best, 40)
                        }
                    }
                }
                val doms = e.optJSONArray("domains")
                if (doms != null && lowerDomain != null) {
                    for (j in 0 until doms.length()) {
                        val dom = doms.optString(j).lowercase()
                        when {
                            dom == lowerDomain -> best = maxOf(best, 100)
                            lowerDomain.endsWith(".$dom") ||
                                dom.endsWith(".$lowerDomain") -> best = maxOf(best, 60)
                        }
                    }
                }
                if (best > 0) scored.add(Scored(e, best))
            }
            scored.sortByDescending { it.score }
            scored.take(MAX_DATASETS).map { s ->
                val e = s.entry
                mapOf(
                    "uuid" to e.optString("uuid"),
                    "title" to e.optString("title"),
                    "username" to e.optString("username"),
                    "password" to e.optString("password"),
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "snapshot decrypt/match failed: ${e.message}")
            emptyList()
        }
    }

    private fun snapshotExists(): Boolean =
        java.io.File(filesDir, SNAPSHOT_NAME).exists()

    // ── Engine IPC ────────────────────────────────────────────────────────────

    private fun queryEngine(packageId: String, domain: String?): Bundle? {
        val engine =
            FlutterEngineCache.getInstance().get(KeeStoneApplication.ENGINE_ID)
                ?: return null
        val messenger = engine.dartExecutor.binaryMessenger
        val latch = CountDownLatch(1)
        var response: Any? = null
        val args = mapOf("packageId" to packageId, "domain" to domain)
        Handler(Looper.getMainLooper()).post {
            MethodChannel(messenger, CHANNEL)
                .invokeMethod("getCredentials", args, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        response = result
                        latch.countDown()
                    }

                    override fun error(code: String, msg: String?, details: Any?) {
                        Log.w(TAG, "autofill channel error: $code $msg")
                        latch.countDown()
                    }

                    override fun notImplemented() {
                        latch.countDown()
                    }
                })
        }
        if (!latch.await(CHANNEL_TIMEOUT_MS, java.util.concurrent.TimeUnit.MILLISECONDS)) {
            Log.w(TAG, "autofill channel timed out")
            return null
        }
        // MethodChannel.Result.success delivers the Dart Map as a HashMap;
        // wrap it into a Bundle so getString()/get() below work uniformly.
        val map = response as? Map<*, *> ?: return null
        return Bundle().apply {
            putString("status", map["status"] as? String)
            putSerializable("candidates", map["candidates"] as? java.io.Serializable)
            putString("filePath", map["filePath"] as? String)
        }
    }

    // ── Response builders ─────────────────────────────────────────────────────

    private fun presentation(label: String): RemoteViews {
        return RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, label)
        }
    }

    /**
     * Datasets whose values are placeholders (empty) and whose tap launches
     * [AutofillAuthActivity]. After a successful biometric/device-credential
     * authentication the framework retries onFillRequest with
     * FLAG_AUTHENTICATION_RESULT and we return the real credentials.
     */
    private fun buildBiometricGatedResponse(
        target: AutofillTarget,
        candidates: List<Map<String, Any?>>,
    ): FillResponse? {
        val builder = FillResponse.Builder()
        var added = 0
        for (c in candidates) {
            if (added >= MAX_DATASETS) break
            val username = c["username"] as? String ?: ""
            val label = buildString {
                (c["title"] as? String)?.takeIf { it.isNotEmpty() }?.let { append(it) }
                if (username.isNotEmpty()) {
                    if (isNotEmpty()) append(" — ")
                    append(username)
                }
                if (isEmpty()) append("KeeStone")
            }
            val allIds = target.usernameIds + target.passwordIds
            if (allIds.isEmpty()) continue
            // Bind the username field with a placeholder so the dataset passes
            // the "at least one field" check; the real fill happens after auth.
            val ds = Dataset.Builder(presentation(label))
                .setValue(allIds.first(), AutofillValue.forText(""))
                .setAuthentication(AutofillAuthActivity.authIntentSender(this).intentSender)
            builder.addDataset(ds.build())
            added++
        }
        if (added == 0) return null
        return builder.build()
    }

    private fun buildDatasetsResponse(
        target: AutofillTarget,
        candidates: List<Map<String, Any?>>,
    ): FillResponse? {
        val builder = FillResponse.Builder()
        var added = 0
        for (c in candidates) {
            if (added >= MAX_DATASETS) break
            val username = c["username"] as? String ?: ""
            val password = c["password"] as? String ?: ""
            val label = buildString {
                (c["title"] as? String)?.takeIf { it.isNotEmpty() }?.let { append(it) }
                if (username.isNotEmpty()) {
                    if (isNotEmpty()) append(" — ")
                    append(username)
                }
                if (isEmpty()) append("KeeStone")
            }
            val ds = Dataset.Builder(presentation(label))
            var hasField = false
            target.usernameIds.forEach {
                ds.setValue(it, AutofillValue.forText(username))
                hasField = true
            }
            target.passwordIds.forEach {
                ds.setValue(it, AutofillValue.forText(password))
                hasField = true
            }
            if (!hasField) continue
            builder.addDataset(ds.build())
            added++
        }
        if (added == 0) return null
        return builder.build()
    }

    private fun buildUnlockResponse(target: AutofillTarget, filePath: String?): FillResponse {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("autofill_unlock", filePath ?: "")
        }
        return authDatasetResponse(target, "Unlock KeeStone", intent, 1001)
    }

    private fun buildOpenAppResponse(target: AutofillTarget): FillResponse {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return authDatasetResponse(target, "KeeStone", intent, 1002)
    }

    private fun authDatasetResponse(
        target: AutofillTarget,
        label: String,
        intent: Intent,
        requestCode: Int,
    ): FillResponse {
        val pi = PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = FillResponse.Builder()
        val allIds = target.usernameIds + target.passwordIds
        if (allIds.isNotEmpty()) {
            // Android 14+ requires every dataset to bind at least one field.
            // Authentication datasets have no value yet, so bind the first
            // field with an empty text value purely to satisfy that check;
            // tapping the dataset launches the auth intent instead of filling.
            val ds = Dataset.Builder(presentation(label))
                .setValue(allIds.first(), AutofillValue.forText(""))
                .setAuthentication(pi.intentSender)
            builder.addDataset(ds.build())
        }
        return builder.build()
    }
}
