package com.inevitabby.nds_save_sync

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.FileNotFoundException

class MainActivity : FlutterActivity() {

    private val channelName = "com.inevitabby.nds_save_sync/saf"
    private val requestCodePickFolder = 1001

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "pickFolder" -> {
                    // Special: Folder picker already open
                    if (pendingResult != null) {
                        result.error("ALREADY_ACTIVE", "A folder picker is already open.", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                    }
                    startActivityForResult(intent, requestCodePickFolder)
                }

                "writeFile" -> {
                    val archiveUri = call.argument<String>("archiveUri")
                    val filename   = call.argument<String>("filename")
                    val bytes      = call.argument<ByteArray>("bytes")
                    val subdir     = call.argument<String?>("subdir")
                    // Special: Missing args
                    if (archiveUri == null || filename == null || bytes == null) {
                        result.error("BAD_ARGS", "archiveUri, filename, and bytes are required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri = Uri.parse(archiveUri)
                        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
                        // Get/create subdir
                        if (subdir != null) {
                            parentDocId = getOrCreateSubdir(treeUri, parentDocId, subdir)
                        }
                        // Get/create file
                        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
                        val fileDocId = findChildDocumentId(treeUri, parentDocId, filename)
                        val fileUri: Uri = if (fileDocId != null) {
                            DocumentsContract.buildDocumentUriUsingTree(treeUri, fileDocId)
                        } else {
                            DocumentsContract.createDocument(
                                contentResolver,
                                parentUri,
                                "application/octet-stream",
                                filename,
                            ) ?: throw Exception("Failed to create document: $filename")
                        }
                        contentResolver.openOutputStream(fileUri, "wt")?.use { stream ->
                            stream.write(bytes)
                        } ?: throw Exception("Failed to open output stream for $filename")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WRITE_FAILED", e.message, null)
                    }
                }

                "readFile" -> {
                    val archiveUri = call.argument<String>("archiveUri")
                    val filename   = call.argument<String>("filename")
                    val subdir     = call.argument<String?>("subdir")
                    // Special: Missing args
                    if (archiveUri == null || filename == null) {
                        result.error("BAD_ARGS", "archiveUri and filename are required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri = Uri.parse(archiveUri)
                        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
                        // Get/create subdir
                        if (subdir != null) {
                            parentDocId = findChildDocumentId(treeUri, parentDocId, subdir)
                                ?: run {
                                    result.error("FILE_NOT_FOUND", "$subdir/$filename not found.", null)
                                    return@setMethodCallHandler
                                }
                        }
                        // Get/create file
                        val fileDocId = findChildDocumentId(treeUri, parentDocId, filename)
                            ?: run {
                                result.error("FILE_NOT_FOUND", "$filename not found.", null)
                                return@setMethodCallHandler
                            }
                        val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, fileDocId)
                        val bytes = contentResolver.openInputStream(fileUri)?.use { it.readBytes() }
                            ?: throw Exception("Failed to open input stream for $filename")
                        result.success(bytes)
                    } catch (e: FileNotFoundException) {
                        result.error("FILE_NOT_FOUND", e.message, null)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // Gets document ID of the direct child (name)
    private fun findChildDocumentId(treeUri: Uri, parentDocId: String, name: String): String? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val docId      = cursor.getString(0)
                val docName    = cursor.getString(1)
                if (docName == name) return docId
            }
        }
        return null
    }
 
    // Gets document ID of the subdir (creating if absent)
    private fun getOrCreateSubdir(treeUri: Uri, parentDocId: String, subdirName: String): String {
        findChildDocumentId(treeUri, parentDocId, subdirName)?.let { return it }
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
        val newUri = DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            subdirName,
        ) ?: throw Exception("Failed to create subdirectory: $subdirName")
        return DocumentsContract.getDocumentId(newUri)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != requestCodePickFolder) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            // User cancelled.
            result.success(null)
            return
        }

        val uri: Uri = data.data ?: run {
            result.error("NO_URI", "No URI returned from folder picker.", null)
            return
        }

        // Take a persistable read+write grant
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        contentResolver.takePersistableUriPermission(uri, flags)

        result.success(uri.toString())
    }
}
