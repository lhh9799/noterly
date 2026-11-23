package uk.co.tdsstudios.noterly.backup

import android.app.backup.BackupAgent
import android.app.backup.BackupDataInput
import android.app.backup.BackupDataOutput
import android.app.backup.FullBackupDataOutput
import android.content.Context
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONObject
import java.io.File

/**
 * Decides what goes into Android's own backup (Google backup), which runs it as Auto Backup thanks to
 * android:fullBackupOnly. The app keeps reminders and settings in one save file, app_flutter/data.json, and the user
 * can leave either out, so instead of that file this agent hands over a copy holding only the parts that are turned
 * on (googleBackupReminders and googleBackupSettings in the save file). After a restore the copy becomes the save file;
 * the part that was left out starts from its defaults.
 */
class NoterlyBackupAgent : BackupAgent() {

    override fun onFullBackup(data: FullBackupDataOutput) {
        val save = readSaveFile() ?: return
        val reminders = save.optBoolean(KEY_BACKUP_REMINDERS, true)
        val settings = save.optBoolean(KEY_BACKUP_SETTINGS, true)

        // With both off the copy is empty: it still replaces the earlier backup, so nothing old comes back
        val copy = JSONObject()
        for (key in save.keys()) {
            if (if (key in REMINDER_KEYS) reminders else settings) copy.put(key, save.get(key))
        }
        val staged = stagedFile(this)
        staged.writeText(copy.toString())
        try {
            fullBackupFile(staged, data)
        } finally {
            staged.delete()
        }
        val parts = listOfNotNull("reminders".takeIf { reminders }, "settings".takeIf { settings })
        Log.i(TAG, "Backed up " + if (parts.isEmpty()) "an empty save file" else parts.joinToString(" and "))
    }

    override fun onRestoreFinished() {
        val staged = stagedFile(this)
        if (!staged.exists()) return
        // App data is cleared before a restore, so the restored copy is all there is
        val save = saveFile(this)
        save.parentFile?.mkdirs()
        if (!staged.renameTo(save)) {
            staged.copyTo(save, overwrite = true)
            staged.delete()
        }
        Log.i(TAG, "Restored the save file from Google backup")
    }

    /** The save file, or its backup copy if the save file cannot be read; null when there is nothing to back up. */
    private fun readSaveFile(): JSONObject? {
        val save = saveFile(this)
        for (file in listOf(save, File(save.path + ".bak"))) {
            if (!file.exists()) continue
            try {
                return JSONObject(file.readText())
            } catch (e: Exception) {
                Log.w(TAG, "Could not read ${file.name}", e)
            }
        }
        return null
    }

    // Key/value backup is not used: android:fullBackupOnly makes Android call onFullBackup instead
    override fun onBackup(oldState: ParcelFileDescriptor?, data: BackupDataOutput?, newState: ParcelFileDescriptor?) {}

    override fun onRestore(data: BackupDataInput?, appVersionCode: Int, newState: ParcelFileDescriptor?) {}

    companion object {
        private const val TAG = "NoterlyBackupAgent"
        private const val KEY_BACKUP_REMINDERS = "googleBackupReminders"
        private const val KEY_BACKUP_SETTINGS = "googleBackupSettings"

        /** Save file entries that belong to the reminders; every other entry is a setting. */
        private val REMINDER_KEYS = setOf("notificationItems", "rev", "appliedWearCommands")

        /** Flutter's documents directory (getApplicationDocumentsDirectory) is getDir("flutter"). */
        private fun saveFile(context: Context) = File(context.getDir("flutter", Context.MODE_PRIVATE), "data.json")

        private fun stagedFile(context: Context) = File(context.filesDir, "google-backup.json")
    }
}
