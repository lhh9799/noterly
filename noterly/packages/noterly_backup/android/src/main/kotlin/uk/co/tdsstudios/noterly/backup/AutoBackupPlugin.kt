package uk.co.tdsstudios.noterly.backup

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/**
 * The 'noterly/backup' channel: picks a folder with the system folder picker, keeps access to it across restarts (a
 * persisted URI permission) and writes the automatic backup file into it. As a plugin it is registered on every Flutter
 * engine, so saves from notification actions and the watch command handler write the backup too. Picking a folder needs
 * the activity, so it only works from the app's UI.
 */
class AutoBackupPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: ActivityPluginBinding? = null
    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activity?.removeActivityResultListener(this)
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFolder" -> pickFolder(result)
            "write" -> {
                val folder = Uri.parse(call.argument<String>("folder")!!)
                val name = call.argument<String>("name")!!
                val bytes = call.argument<String>("content")!!.toByteArray(Charsets.UTF_8)
                io.execute {
                    val error = try {
                        write(folder, name, bytes)
                        null
                    } catch (e: Exception) {
                        Log.w(TAG, "Could not write $name", e)
                        e
                    }
                    main.post {
                        if (error == null) result.success(null) else result.error("write_failed", error.toString(), null)
                    }
                }
            }
            "canWrite" -> result.success(canWrite(call.argument<String>("folder")!!))
            "release" -> {
                release(call.argument<String>("folder")!!)
                result.success(null)
            }
            "hasGooglePlayServices" -> result.success(hasGooglePlayServices())
            else -> result.notImplemented()
        }
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val activity = activity?.activity ?: return result.error("no_activity", "Picking a folder needs the app's UI", null)
        if (pendingPick != null) return result.error("busy", "The folder picker is already open", null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
        )
        activity.startActivityForResult(intent, REQUEST_PICK_FOLDER)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK_FOLDER) return false
        val result = pendingPick ?: return true
        pendingPick = null

        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        try {
            context.contentResolver.takePersistableUriPermission(tree, READ_WRITE)
            result.success(mapOf("uri" to tree.toString(), "name" to displayName(tree)))
        } catch (e: Exception) {
            Log.w(TAG, "Could not keep access to $tree", e)
            result.error("no_access", e.toString(), null)
        }
        return true
    }

    private fun displayName(tree: Uri): String {
        val folder = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        context.contentResolver.query(folder, arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0)?.let { name -> return name }
        }
        return tree.lastPathSegment ?: tree.toString()
    }

    /** Google Play services runs Google backup; the manifest's <queries> lets the app see it. */
    private fun hasGooglePlayServices() = try {
        context.packageManager.getPackageInfo(GOOGLE_PLAY_SERVICES, 0).applicationInfo?.enabled == true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    /** Whether the app still holds write access to the folder (it loses it when the app is reinstalled). */
    private fun canWrite(folder: String) =
        context.contentResolver.persistedUriPermissions.any { it.uri.toString() == folder && it.isWritePermission }

    private fun release(folder: String) {
        try {
            context.contentResolver.releasePersistableUriPermission(Uri.parse(folder), READ_WRITE)
        } catch (e: SecurityException) {
            // Access was already gone
        }
    }

    /** Replaces the file [name] in the folder, creating it the first time. */
    private fun write(tree: Uri, name: String, bytes: ByteArray) {
        val resolver = context.contentResolver
        val treeId = DocumentsContract.getTreeDocumentId(tree)
        val folder = DocumentsContract.buildDocumentUriUsingTree(tree, treeId)
        val existing = findChild(resolver, tree, treeId, name)
        val file = existing ?: create(resolver, folder, name)
        try {
            // "wt" truncates, so a shorter backup leaves none of the old bytes behind
            resolver.openOutputStream(file, "wt")!!.use { it.write(bytes) }
        } catch (e: SecurityException) {
            throw e
        } catch (e: Exception) {
            // Providers that do not support "wt" (or a file deleted meanwhile): write a fresh file instead
            Log.i(TAG, "Writing $name in place failed, replacing it", e)
            if (existing != null) DocumentsContract.deleteDocument(resolver, existing)
            resolver.openOutputStream(create(resolver, folder, name), "w")!!.use { it.write(bytes) }
        }
    }

    private fun create(resolver: ContentResolver, folder: Uri, name: String) =
        DocumentsContract.createDocument(resolver, folder, MIME_TYPE, name)
            ?: throw IllegalStateException("Could not create $name")

    private fun findChild(resolver: ContentResolver, tree: Uri, treeId: String, name: String): Uri? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, treeId)
        resolver.query(children, arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use {
                while (it.moveToNext()) {
                    if (it.getString(1) == name) return DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
                }
            }
        return null
    }

    companion object {
        private const val TAG = "AutoBackupPlugin"
        private const val CHANNEL = "noterly/backup"
        private const val MIME_TYPE = "application/json"
        private const val GOOGLE_PLAY_SERVICES = "com.google.android.gms"
        private const val REQUEST_PICK_FOLDER = 0x4E42
        private const val READ_WRITE = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

        // One thread for every engine in the process, so two saves never write the file at the same time
        private val io = Executors.newSingleThreadExecutor()
    }
}
