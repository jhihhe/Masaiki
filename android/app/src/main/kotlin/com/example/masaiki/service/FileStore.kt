package com.example.masaiki.service

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import java.io.OutputStream

/**
 * Scoped-storage friendly image writer. Saves to Pictures/Masaiki via MediaStore,
 * no runtime permission required on any supported API level.
 */
object FileStore {

    fun saveToPictures(context: Context, bitmap: Bitmap, displayName: String): Uri? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, sanitize(displayName))
            put(MediaStore.Images.Media.MIME_TYPE, mimeFor(displayName))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Masaiki")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            else
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI

        val uri = resolver.insert(collection, values) ?: return null
        val format = if (displayName.endsWith(".png", true)) Bitmap.CompressFormat.PNG
                     else Bitmap.CompressFormat.JPEG
        resolver.openOutputStream(uri).use { out: OutputStream? ->
            if (out == null) return null
            bitmap.compress(format, /* quality = */ 92, out)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri
    }

    private fun sanitize(name: String): String =
        name.replace(Regex("[^a-zA-Z0-9._\\-\\u4e00-\\u9fa5]"), "_")

    private fun mimeFor(name: String): String = when {
        name.endsWith(".png", true)              -> "image/png"
        name.endsWith(".heic", true)             -> "image/heic"
        name.endsWith(".webp", true)             -> "image/webp"
        else                                     -> "image/jpeg"
    }
}
