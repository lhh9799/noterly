package uk.co.tdsstudios.noterly.wear_sync

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The 'noterly/wear' channel. As a plugin it is registered on every Flutter engine, so the Dart side can send a
 * snapshot from the main isolate, from notification actions in the background, and from the headless watch
 * command handler alike.
 */
class WearSyncPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "sendSnapshot" -> sendSnapshot(call.argument<String>("json")!!, result)
                "fetchCommands" -> fetchCommands(result)
                "deleteCommand" -> deleteCommand(call.argument<String>("uri")!!, result)
                "applyBridgeTags" -> {
                    applyBridgeTags(call.argument<Map<String, String>>("tags").orEmpty())
                    result.success(null)
                }
                "headlessDone" -> {
                    WearCommandRunner.onDartFinished()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            // No Play services, or the Wearable API is unavailable: the phone app works as before
            Log.w(TAG, "${call.method} failed", e)
            result.success(null)
        }
    }

    private val dataClient: DataClient get() = Wearable.getDataClient(context)

    private fun sendSnapshot(json: String, result: MethodChannel.Result) {
        val request = PutDataMapRequest.create(SNAPSHOT_PATH).apply {
            dataMap.putString(KEY_JSON, json)
        }.asPutDataRequest().setUrgent()
        dataClient.putDataItem(request)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener {
                Log.w(TAG, "Failed to send snapshot", it)
                result.success(null)
            }
    }

    private fun fetchCommands(result: MethodChannel.Result) {
        val uri = Uri.Builder().scheme(PutDataRequest.WEAR_URI_SCHEME).path(COMMAND_PREFIX).build()
        dataClient.getDataItems(uri, DataClient.FILTER_PREFIX)
            .addOnSuccessListener { buffer ->
                val commands = buffer.mapNotNull { item ->
                    val json = DataMapItem.fromDataItem(item).dataMap.getString(KEY_JSON) ?: return@mapNotNull null
                    mapOf("uri" to item.uri.toString(), "json" to json)
                }
                buffer.release()
                result.success(commands)
            }
            .addOnFailureListener {
                Log.w(TAG, "Failed to read commands", it)
                result.success(emptyList<Map<String, String>>())
            }
    }

    private fun deleteCommand(uri: String, result: MethodChannel.Result) {
        dataClient.deleteDataItems(Uri.parse(uri))
            .addOnCompleteListener { result.success(null) }
    }

    /**
     * flutter_local_notifications cannot set a bridge tag, so re-post the shown notifications with one. The watch
     * excludes the tags of sends it already showed by itself while the phone was away.
     */
    @Suppress("DEPRECATION")
    private fun applyBridgeTags(tags: Map<String, String>) {
        val manager = context.getSystemService(NotificationManager::class.java)
        for (shown in manager.activeNotifications) {
            val tag = tags[shown.id.toString()] ?: continue
            if (Notification.WearableExtender(shown.notification).bridgeTag == tag) continue

            val builder = Notification.Builder.recoverBuilder(context, shown.notification)
                .extend(Notification.WearableExtender(shown.notification).setBridgeTag(tag))
                .setOnlyAlertOnce(true)
            manager.notify(shown.tag, shown.id, builder.build())
        }
    }

    companion object {
        private const val TAG = "WearSync"
        const val CHANNEL = "noterly/wear"
        const val SNAPSHOT_PATH = "/noterly/snapshot"
        const val COMMAND_PREFIX = "/noterly/cmd"
        const val SYNC_REQUEST_PATH = "/noterly/sync-request"
        const val KEY_JSON = "json"
    }
}
