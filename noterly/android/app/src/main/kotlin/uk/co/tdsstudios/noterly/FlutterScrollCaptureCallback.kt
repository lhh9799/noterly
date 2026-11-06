package uk.co.tdsstudios.noterly

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PorterDuff
import android.graphics.Rect
import android.os.CancellationSignal
import android.view.ScrollCaptureCallback
import android.view.ScrollCaptureSession
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.function.Consumer

/**
 * Answers the system's scroll capture requests for the Flutter view by asking the Dart side (lib/managers/scroll_capture.dart)
 * to find the list, scroll it and render the requested part. Android calls every method on the UI thread, which is also
 * where the method channel must be used.
 */
class FlutterScrollCaptureCallback(private val channel: MethodChannel) : ScrollCaptureCallback {

    private abstract class Reply : MethodChannel.Result {
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = success(null)
        override fun notImplemented() = success(null)
    }

    override fun onScrollCaptureSearch(signal: CancellationSignal, onReady: Consumer<Rect>) {
        channel.invokeMethod("search", null, object : Reply() {
            override fun success(result: Any?) {
                val bounds = result as? Map<*, *>
                if (bounds == null) {
                    onReady.accept(Rect()) // No list that can scroll on screen
                    return
                }
                onReady.accept(Rect(bounds.int("left"), bounds.int("top"), bounds.int("right"), bounds.int("bottom")))
            }
        })
    }

    override fun onScrollCaptureStart(session: ScrollCaptureSession, signal: CancellationSignal, onReady: Runnable) {
        channel.invokeMethod("start", null, object : Reply() {
            override fun success(result: Any?) = onReady.run()
        })
    }

    override fun onScrollCaptureImageRequest(
        session: ScrollCaptureSession,
        signal: CancellationSignal,
        captureArea: Rect,
        onComplete: Consumer<Rect>,
    ) {
        channel.invokeMethod("capture", mapOf("top" to captureArea.top, "bottom" to captureArea.bottom), object : Reply() {
            override fun success(result: Any?) {
                val reply = result as? Map<*, *>
                val pixels = reply?.get("pixels") as? ByteArray
                if (reply == null || pixels == null || signal.isCanceled) {
                    onComplete.accept(Rect()) // Nothing more in that direction
                    return
                }
                val width = reply.int("width")
                val height = reply.int("height")
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(pixels))
                val canvas = session.surface.lockHardwareCanvas()
                try {
                    canvas.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
                    canvas.drawBitmap(bitmap, 0f, 0f, null)
                } finally {
                    session.surface.unlockCanvasAndPost(canvas)
                    bitmap.recycle()
                }
                onComplete.accept(Rect(captureArea.left, reply.int("top"), captureArea.right, reply.int("bottom")))
            }
        })
    }

    override fun onScrollCaptureEnd(onReady: Runnable) {
        channel.invokeMethod("end", null, object : Reply() {
            override fun success(result: Any?) = onReady.run()
        })
    }

    private fun Map<*, *>.int(key: String) = (get(key) as Number).toInt()
}
