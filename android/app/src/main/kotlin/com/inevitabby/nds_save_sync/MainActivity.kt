package com.inevitabby.nds_save_sync

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
                    if (archiveUri == null || filename == null || bytes == null) {
                        result.error("BAD_ARGS", "archiveUri, filename, and bytes are required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri    = Uri.parse(archiveUri)
                        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
                        if (subdir != null) {
                            parentDocId = ensureDir(treeUri, parentDocId, subdir)
                        }
                        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
                        val fileDocId = findChild(treeUri, parentDocId, filename)
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
                    if (archiveUri == null || filename == null) {
                        result.error("BAD_ARGS", "archiveUri and filename are required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri    = Uri.parse(archiveUri)
                        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
                        if (subdir != null) {
                            parentDocId = findChild(treeUri, parentDocId, subdir)
                                ?: run {
                                    result.error("FILE_NOT_FOUND", "$subdir/$filename not found.", null)
                                    return@setMethodCallHandler
                                }
                        }
                        val fileDocId = findChild(treeUri, parentDocId, filename)
                            ?: run {
                                result.error("FILE_NOT_FOUND", "$filename not found.", null)
                                return@setMethodCallHandler
                            }
                        val fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, fileDocId)
                        val bytes   = contentResolver.openInputStream(fileUri)?.use { it.readBytes() }
                            ?: throw Exception("Failed to open input stream for $filename")
                        result.success(bytes)
                    } catch (e: FileNotFoundException) {
                        result.error("FILE_NOT_FOUND", e.message, null)
                    } catch (e: Exception) {
                        result.error("READ_FAILED", e.message, null)
                    }
                }

                "listFiles" -> {
                    val archiveUri = call.argument<String>("archiveUri")
                    val subdir     = call.argument<String?>("subdir")
                    if (archiveUri == null) {
                        result.error("BAD_ARGS", "archiveUri is required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val treeUri    = Uri.parse(archiveUri)
                        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
                        if (subdir != null) {
                            parentDocId = findChild(treeUri, parentDocId, subdir)
                                ?: run {
                                    result.success(emptyList<String>())
                                    return@setMethodCallHandler
                                }
                        }
                        result.success(listFiles(treeUri, parentDocId))
                    } catch (e: Exception) {
                        result.error("LIST_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // Returns the document ID of a direct child by name
    private fun findChild(treeUri: Uri, parentDocId: String, name: String): String? {
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
                if (cursor.getString(1) == name) return cursor.getString(0)
            }
        }
        return null
    }

    // Returns the document ID of name as a subdirectory (creates it if absent)
    private fun ensureDir(treeUri: Uri, parentDocId: String, name: String): String {
        findChild(treeUri, parentDocId, name)?.let { return it }
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
        val newUri = DocumentsContract.createDocument(
            contentResolver,
            parentUri,
            DocumentsContract.Document.MIME_TYPE_DIR,
            name,
        ) ?: throw Exception("Failed to create subdirectory: $name")
        return DocumentsContract.getDocumentId(newUri)
    }

    // Returns display names of all non-directory children.
    private fun listFiles(treeUri: Uri, parentDocId: String): List<String> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val names = mutableListOf<String>()
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(2) != DocumentsContract.Document.MIME_TYPE_DIR) {
                    names.add(cursor.getString(1))
                }
            }
        }
        return names
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != requestCodePickFolder) return

        val result = pendingResult ?: return
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(null)
            return
        }

        val uri: Uri = data.data ?: run {
            result.error("NO_URI", "No URI returned from folder picker.", null)
            return
        }

        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        contentResolver.takePersistableUriPermission(uri, flags)

        result.success(uri.toString())
    }
}
