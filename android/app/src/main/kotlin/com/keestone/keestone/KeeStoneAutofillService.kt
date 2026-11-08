package com.keestone.keestone

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.CountDownLatch
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

private const val TAG = "KeeStoneAutofill"
private const val CHANNEL = "com.keestone.keestone/autofill"
private const val CHANNEL_TIMEOUT_MS = 2500L
private const val MAX_DATASETS = 10

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
        val structures = request.fillRequestContexts.map { it.structure }
        val target = structures.firstNotNullOfOrNull { parseStructure(it) }
        if (target == null) {
            callback.onSuccess(null)
            return
        }

        val result = queryEngine(target.packageName, target.domain)
        if (result == null) {
            callback.onSuccess(buildOpenAppResponse(target))
            return
        }

        when (result.getString("status")) {
            "unlocked" -> {
                @Suppress("UNCHECKED_CAST")
                val candidates =
                    (result.get("candidates") as? List<Map<String, Any?>>) ?: emptyList()
                if (candidates.isEmpty()) {
                    callback.onSuccess(buildOpenAppResponse(target))
                } else {
                    buildDatasetsResponse(target, candidates)?.let { callback.onSuccess(it) }
                        ?: callback.onSuccess(buildOpenAppResponse(target))
                }
            }
            "locked" -> callback.onSuccess(buildUnlockResponse(target, result.getString("filePath")))
            else -> callback.onSuccess(buildOpenAppResponse(target))
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
        // WebView domain (API 28+).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val d = node.domain
            if (!d.isNullOrEmpty()) onDomain(d)
        }
        val html = node.htmlInfo
        if (html != null) {
            var inputType = ""
            var action: String? = null
            for (entry in html.attributes) {
                when (entry.key.lowercase()) {
                    "type" -> inputType = entry.value.lowercase()
                    "action", "href" -> if (action == null) action = entry.value
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

    // ── Engine IPC ────────────────────────────────────────────────────────────

    private fun queryEngine(packageId: String, domain: String?): Bundle? {
        val engine: FlutterEngine? =
            FlutterEngineCache.getInstance().get(KeeStoneApplication.ENGINE_ID)
                ?: return null
        val latch = CountDownLatch(1)
        var response: Any? = null
        val args = mapOf("packageId" to packageId, "domain" to domain)
        Handler(Looper.getMainLooper()).post {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
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
        return response as? Bundle
    }

    // ── Response builders ─────────────────────────────────────────────────────

    private fun presentation(label: String): RemoteViews {
        return RemoteViews(packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, label)
        }
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
        if ((target.usernameIds + target.passwordIds).isNotEmpty()) {
            builder.addDataset(
                Dataset.Builder(presentation(label))
                    .setAuthentication(pi.intentSender)
                    .build(),
            )
        }
        return builder.build()
    }
}
