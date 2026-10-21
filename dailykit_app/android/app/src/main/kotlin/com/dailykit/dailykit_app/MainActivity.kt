package com.dailykit.dailykit_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dailykit.dailykit_app/file_picker"
    private val PICK_FILE_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickBackupFile") {
                pendingResult = result
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                    }
                    startActivityForResult(intent, PICK_FILE_REQUEST_CODE)
                } catch (e: Exception) {
                    result.error("LAUNCH_ERROR", e.message, null)
                    pendingResult = null
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_FILE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri: Uri = data.data!!
                try {
                    val content = contentResolver.openInputStream(uri)?.use { stream ->
                        BufferedReader(InputStreamReader(stream)).readText()
                    }
                    val fileName = uri.lastPathSegment ?: "backup.json"
                    pendingResult?.success(mapOf("name" to fileName, "content" to content))
                } catch (e: Exception) {
                    pendingResult?.error("READ_ERROR", e.message, null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}
