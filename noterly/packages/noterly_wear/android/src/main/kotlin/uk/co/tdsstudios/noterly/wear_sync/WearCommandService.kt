package uk.co.tdsstudios.noterly.wear_sync

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/** Wakes the phone app for watch commands and sync requests, even when the app is not running. */
class WearCommandService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val hasCommand = dataEvents.any {
            it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path?.startsWith(WearSyncPlugin.COMMAND_PREFIX) == true
        }
        // Runs on a background thread; waiting keeps the service alive until Dart has applied the commands
        if (hasCommand) WearCommandRunner.runAndWait(applicationContext)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == WearSyncPlugin.SYNC_REQUEST_PATH) WearCommandRunner.runAndWait(applicationContext)
    }
}
