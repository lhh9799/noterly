package uk.co.tdsstudios.noterly

import android.os.Bundle
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
