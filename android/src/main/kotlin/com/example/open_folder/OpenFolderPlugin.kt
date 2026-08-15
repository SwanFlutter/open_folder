package com.example.open_folder

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
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
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "open_folder")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
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

            // اول تلاش برای استفاده از DocumentsContract (برای Android 8+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (tryOpenWithDocumentsContract(folder, result)) {
                    return
                }
            }

            // روش دوم: استفاده از FileProvider
            if (tryOpenWithFileProvider(folder, result)) {
                return
            }

            // روش سوم: باز کردن با file managers خاص
            if (tryOpenWithSpecificFileManagers(folder, result)) {
                return
            }

            // روش چهارم: Intent عمومی
            if (tryOpenWithGenericIntent(folder, result)) {
                return
            }

            // اگر هیچکدام کار نکرد
            val errorResult = JSONObject().apply {
                put("type", "noAppToOpen")
                put("message", "No application available to open folders on this device")
            }
            result.success(errorResult.toString())

        } catch (e: Exception) {
            val errorResult = JSONObject().apply {
                put("type", "error")
                put("message", "Failed to open folder: ${e.message}")
            }
            result.success(errorResult.toString())
        }
    }

    private fun tryOpenWithDocumentsContract(folder: File, result: Result): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        
        return try {
            // تبدیل مسیر به Document Tree URI
            val externalStorageDir = android.os.Environment.getExternalStorageDirectory()
            val relativePath = folder.absolutePath.removePrefix(externalStorageDir.absolutePath)
                .removePrefix("/")
            
            // ساخت URI صحیح برای DocumentsUI
            val treeUri = if (relativePath.isEmpty()) {
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:"
                )
            } else {
                DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    "primary:$relativePath"
                )
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(treeUri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            context.startActivity(intent)
            val successResult = JSONObject().apply {
                put("type", "done")
                put("message", "Folder opened: ${folder.absolutePath}")
            }
            result.success(successResult.toString())
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun tryOpenWithFileProvider(folder: File, result: Result): Boolean {
        return try {
            val authority = "${context.packageName}.fileprovider"
            val uri = FileProvider.getUriForFile(context, authority, folder)

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            context.startActivity(intent)
            val successResult = JSONObject().apply {
                put("type", "done")
                put("message", "Folder opened with FileProvider: ${folder.absolutePath}")
            }
            result.success(successResult.toString())
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun tryOpenWithSpecificFileManagers(folder: File, result: Result): Boolean {
        val fileManagers = listOf(
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.mi.android.globalFileexplorer",
            "com.estrongs.android.pop",
            "com.speedsoftware.explorer",
            "nextapp.fx",
            "com.ghisler.android.TotalCommander",
            "com.alphainventor.filemanager",
            "pl.solidexplorer2",
            "com.lonelycatgames.Xplore"
        )

        // محاسبه مسیر نسبی
        val externalStorageDir = android.os.Environment.getExternalStorageDirectory()
        val absolutePath = folder.absolutePath
        
        for (packageName in fileManagers) {
            try {
                val intent = when {
                    // برای Google Files و Documents UI
                    packageName.contains("documentsui") -> {
                        val relativePath = absolutePath.removePrefix(externalStorageDir.absolutePath)
                            .removePrefix("/")
                        
                        val treeUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            DocumentsContract.buildDocumentUri(
                                "com.android.externalstorage.documents",
                                "primary:$relativePath"
                            )
                        } else {
                            Uri.fromFile(folder)
                        }

                        Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(treeUri, DocumentsContract.Document.MIME_TYPE_DIR)
                            setPackage(packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                    }
                    // برای بقیه file managers
                    else -> {
                        Intent(Intent.ACTION_VIEW).apply {
                            data = Uri.fromFile(folder)
                            setPackage(packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }
                }

                context.startActivity(intent)
                val successResult = JSONObject().apply {
                    put("type", "done")
                    put("message", "Folder opened with $packageName: $absolutePath")
                }
                result.success(successResult.toString())
                return true
            } catch (e: ActivityNotFoundException) {
                // این file manager نصب نیست، برو به بعدی
                continue
            } catch (e: Exception) {
                // خطای دیگه، برو به بعدی
                continue
            }
        }
        
        return false
    }

    private fun tryOpenWithGenericIntent(folder: File, result: Result): Boolean {
        return try {
            // تلاش با Intent عمومی
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.fromFile(folder)
                type = "resource/folder"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addCategory(Intent.CATEGORY_DEFAULT)
            }

            // بررسی اینکه آیا اپلیکیشنی برای این Intent وجود داره
            val packageManager = context.packageManager
            val activities = packageManager.queryIntentActivities(intent, 0)
            
            if (activities.isNotEmpty()) {
                context.startActivity(intent)
                val successResult = JSONObject().apply {
                    put("type", "done")
                    put("message", "Folder opened: ${folder.absolutePath}")
                }
                result.success(successResult.toString())
                return true
            }
            
            false
        } catch (e: Exception) {
            false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}