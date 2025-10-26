package com.example.open_folder

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject
import java.io.File

/** OpenFolderPlugin */
class OpenFolderPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "open_folder")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "openFolder" -> {
                val folderPath = call.argument<String>("folder_path")
                if (folderPath != null) {
                    openFolder(folderPath, result)
                } else {
                    val errorResult = JSONObject().apply {
                        put("type", "error")
                        put("message", "Folder path is required")
                    }
                    result.success(errorResult.toString())
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun openFolder(folderPath: String, result: Result) {
        try {
            val folder = File(folderPath)
            
            if (!folder.exists()) {
                val errorResult = JSONObject().apply {
                    put("type", "fileNotFound")
                    put("message", "Folder does not exist: $folderPath")
                }
                result.success(errorResult.toString())
                return
            }

            if (!folder.isDirectory) {
                val errorResult = JSONObject().apply {
                    put("type", "error")
                    put("message", "Path is not a directory: $folderPath")
                }
                result.success(errorResult.toString())
                return
            }

            val intent = Intent(Intent.ACTION_VIEW)
            val uri: Uri

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // For Android 7.0 and above, use FileProvider
                uri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    folder
                )
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                // For older versions, use file URI directly
                uri = Uri.fromFile(folder)
            }

            intent.setDataAndType(uri, "resource/folder")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            // Try to open with file manager
            try {
                context.startActivity(intent)
                val successResult = JSONObject().apply {
                    put("type", "done")
                    put("message", "Folder opened successfully")
                }
                result.success(successResult.toString())
            } catch (e: Exception) {
                // If no app can handle the folder, try alternative approaches
                openFolderAlternative(folderPath, result)
            }

        } catch (e: Exception) {
            val errorResult = JSONObject().apply {
                put("type", "error")
                put("message", "Failed to open folder: ${e.message}")
            }
            result.success(errorResult.toString())
        }
    }

    private fun openFolderAlternative(folderPath: String, result: Result) {
        try {
            // Try to open with a generic intent
            val intent = Intent(Intent.ACTION_GET_CONTENT)
            intent.type = "*/*"
            intent.addCategory(Intent.CATEGORY_OPENABLE)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            
            // Try to set the initial directory (this may not work on all devices)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                intent.putExtra("android.provider.extra.INITIAL_URI", Uri.fromFile(File(folderPath)))
            }

            context.startActivity(Intent.createChooser(intent, "Open Folder").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            
            val successResult = JSONObject().apply {
                put("type", "done")
                put("message", "File picker opened")
            }
            result.success(successResult.toString())
            
        } catch (e: Exception) {
            val errorResult = JSONObject().apply {
                put("type", "noAppToOpen")
                put("message", "No application available to open folders")
            }
            result.success(errorResult.toString())
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
