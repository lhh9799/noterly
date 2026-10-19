package uk.co.tdsstudios.noterly.wear_sync

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Runs the Dart entry point `wearCommandEntryPoint` (lib/main.dart) in a headless Flutter engine. It applies the
 * queued watch commands through AppManager, sends a fresh snapshot, then calls `headlessDone`. Like the background
 * handler of notification actions, it then asks the main isolate, if any, to reload.
 */
object WearCommandRunner {
    private const val TAG = "WearCommandRunner"
    private const val ENTRY_POINT = "wearCommandEntryPoint"
    private const val TIMEOUT_SECONDS = 30L

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var runAgain = false
    private var appContext: Context? = null
    private val waiting = mutableListOf<CountDownLatch>()

    /** Starts a run (or queues another one if a run is in progress) and waits for it, up to a timeout. */
    fun runAndWait(context: Context) {
        val latch = CountDownLatch(1)
        main.post { start(context, latch) }
        if (!latch.await(TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            Log.w(TAG, "Headless run timed out")
            main.post { finish(force = true) }
        }
    }

    private fun start(context: Context, latch: CountDownLatch) {
        appContext = context.applicationContext
        waiting += latch
        if (engine != null) {
            // Commands that arrive during a run are picked up by one more run
            runAgain = true
            return
        }
        launch()
    }

    private fun launch() {
        val context = appContext ?: return release()
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            engine = FlutterEngine(context).also {
                it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRY_POINT))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start headless engine", e)
            engine = null
            release()
        }
    }

    fun onDartFinished() {
        main.post { finish(force = false) }
    }

    private fun finish(force: Boolean) {
        engine?.destroy()
        engine = null

        if (runAgain && !force) {
            runAgain = false
            launch()
            return
        }
        runAgain = false
        release()
    }

    private fun release() {
        waiting.forEach { it.countDown() }
        waiting.clear()
    }
}
