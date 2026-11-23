package uk.co.tdsstudios.noterly

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var scrollCaptureChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        scrollCaptureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noterly/scroll_capture")

        // Settings > Language opens Android's per-app language screen for Noterly (the languages come from
        // res/xml/locales_config.xml); the result is whether it opened
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "noterly/app_settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppLanguage" -> try {
                    startActivity(Intent(Settings.ACTION_APP_LOCALE_SETTINGS, Uri.fromParts("package", packageName, null)))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPostCreate(savedInstanceState: Bundle?) {
        super.onPostCreate(savedInstanceState)
        // Let the system screenshot tool (Galaxy scroll capture, Android's "Capture more") scroll and capture the list
        val channel = scrollCaptureChannel ?: return
        val flutterView = findFlutterView(window.decorView) ?: return
        flutterView.scrollCaptureHint = View.SCROLL_CAPTURE_HINT_INCLUDE
        flutterView.setScrollCaptureCallback(FlutterScrollCaptureCallback(channel))
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                findFlutterView(view.getChildAt(i))?.let { return it }
            }
        }
        return null
    }
}
