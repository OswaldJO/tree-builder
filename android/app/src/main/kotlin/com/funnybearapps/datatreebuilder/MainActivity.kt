package com.funnybearapps.datatreebuilder

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.treebuilder/tree_scanner"
    private val progressChannelName = "com.treebuilder/scan_progress"
    private val pickDirectoryRequestCode = 43781

    private var pendingPickResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scanExecutor = Executors.newSingleThreadExecutor()
    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, progressChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        progressSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        progressSink = null
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> {
                        pendingPickResult = result
                        val intent =
                            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
                                )
                            }
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, pickDirectoryRequestCode)
                    }

                    "scanDirectory" -> {
                        val uriString = call.argument<String>("uri")
                        val maxDepth = call.argument<Int>("maxDepth")
                        if (uriString == null) {
                            result.error("invalid_args", "Missing uri", null)
                            return@setMethodCallHandler
                        }

                        val treeUri = Uri.parse(uriString)
                        scanExecutor.execute {
                            try {
                                val scanResult = scanDirectory(treeUri, maxDepth)
                                mainHandler.post { result.success(scanResult) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("scan_failed", e.message, null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != pickDirectoryRequestCode) {
            return
        }

        val callback = pendingPickResult
        pendingPickResult = null

        if (callback == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            callback.success(null)
            return
        }

        val treeUri: Uri? = data?.data
        if (treeUri == null) {
            callback.success(null)
            return
        }

        val takeFlags =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        contentResolver.takePersistableUriPermission(treeUri, takeFlags)
        callback.success(treeUri.toString())
    }

    private fun emitProgress(folders: Int, files: Int, current: String?) {
        mainHandler.post {
            progressSink?.success(
                mapOf(
                    "folders" to folders,
                    "files" to files,
                    "current" to current,
                ),
            )
        }
    }

    private fun scanDirectory(treeUri: Uri, maxDepth: Int?): Map<String, Any?> {
        val rootDoc =
            DocumentFile.fromTreeUri(this, treeUri)
                ?: throw IllegalStateException("Unable to access selected directory.")

        val counters = ScanCounters()
        val rootName = rootDoc.name ?: "root"
        val rootNode = buildNode(rootDoc, currentDepth = 1, maxDepth = maxDepth, counters = counters)

        return mapOf(
            "rootName" to rootName,
            "rootPath" to treeUri.toString(),
            "root" to rootNode,
        )
    }

    private class ScanCounters {
        var folders: Int = 0
        var files: Int = 0
        var itemsSinceEmit: Int = 0
    }

    private fun buildNode(
        document: DocumentFile,
        currentDepth: Int,
        maxDepth: Int?,
        counters: ScanCounters,
    ): Map<String, Any?> {
        val children = mutableListOf<Map<String, Any?>>()
        val entries =
            document.listFiles().sortedWith(
                compareBy<DocumentFile>({ !it.isDirectory }, { it.name?.lowercase() ?: "" }),
            )

        for (entry in entries) {
            val name = entry.name ?: continue

            if (entry.isDirectory) {
                counters.folders++
            } else {
                counters.files++
            }

            counters.itemsSinceEmit++
            if (counters.itemsSinceEmit >= 25) {
                counters.itemsSinceEmit = 0
                emitProgress(counters.folders, counters.files, name)
            }

            if (entry.isDirectory) {
                val child =
                    if (maxDepth != null && currentDepth >= maxDepth) {
                        mapOf(
                            "name" to name,
                            "isDirectory" to true,
                            "children" to emptyList<Map<String, Any?>>(),
                        )
                    } else {
                        buildNode(entry, currentDepth + 1, maxDepth, counters)
                    }
                children.add(child)
            } else {
                children.add(
                    mapOf(
                        "name" to name,
                        "isDirectory" to false,
                        "children" to emptyList<Map<String, Any?>>(),
                    ),
                )
            }
        }

        return mapOf(
            "name" to (document.name ?: ""),
            "isDirectory" to true,
            "children" to children,
        )
    }
}
