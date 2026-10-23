package com.fayma.app

import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fayma/sms")
            .setMethodCallHandler { call, result ->
                if (call.method != "send") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                    result.error("bad_args", "phone et message sont requis", null)
                    return@setMethodCallHandler
                }

                try {
                    val manager = smsManager()
                    // Découpe en plusieurs SMS si le texte dépasse 160 caractères.
                    val parts = manager.divideMessage(message)
                    manager.sendMultipartTextMessage(phone, null, parts, null, null)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("send_failed", e.message, null)
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun smsManager(): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }
}