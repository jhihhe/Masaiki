package com.example.masaiki

import android.app.Application
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.RectF
import android.net.Uri
import android.provider.OpenableColumns
import android.renderscript.RenderScript
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.masaiki.model.BlurRegion
import com.example.masaiki.model.BlurType
import com.example.masaiki.model.ImageItem
import com.example.masaiki.service.FaceDetector
import com.example.masaiki.service.FileStore
import com.example.masaiki.service.ImageProcessor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class AppViewModel(app: Application) : AndroidViewModel(app) {

    val items = mutableStateListOf<ImageItem>()
    var selectedItemID by mutableStateOf<UUID?>(null)
        private set
    var currentBlurType by mutableStateOf(BlurType.GAUSSIAN)
    var currentIntensity by mutableStateOf(1.0f)
    var lastError by mutableStateOf<String?>(null)

    @Suppress("DEPRECATION")
    private val rs: RenderScript by lazy { RenderScript.create(getApplication<Application>()) }

    val selectedItem: ImageItem?
        get() = items.firstOrNull { it.id == selectedItemID }

    fun select(id: UUID) { selectedItemID = id }

    fun importUris(uris: List<Uri>) {
        val context = getApplication<Application>().applicationContext
        viewModelScope.launch {
            for (uri in uris) {
                try {
                    val (bitmap, name, size) = withContext(Dispatchers.IO) { readImage(context, uri) }
                    val item = ImageItem(uri = uri, displayName = name, bitmap = bitmap, originalFileSize = size)
                    items.add(item)
                    selectedItemID = item.id
                    detectFaces(item)
                } catch (t: Throwable) {
                    lastError = t.localizedMessage ?: t.toString()
                }
            }
        }
    }

    private fun readImage(context: Context, uri: Uri): Triple<Bitmap, String, Long> {
        val resolver = context.contentResolver
        var name = "image.jpg"
        var size = 0L
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    name = c.getString(0) ?: name
                    size = c.getLong(1)
                }
            }
        val bytes = resolver.openInputStream(uri).use { it?.readBytes() ?: ByteArray(0) }
        val opts = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            ?: error("无法解码图片: $name")
        return Triple(bitmap, name, size)
    }

    fun autoDetectFaces(item: ImageItem) {
        viewModelScope.launch { detectFaces(item) }
    }

    private suspend fun detectFaces(item: ImageItem) {
        if (item.isProcessing) return
        item.isProcessing = true
        item.errorMessage = null
        try {
            val faces = FaceDetector.detect(item.bitmap)
            for (face in faces) {
                val expanded = RectF(
                    face.left - face.width() * 0.1f,
                    face.top - face.height() * 0.1f,
                    face.right + face.width() * 0.1f,
                    face.bottom + face.height() * 0.1f
                )
                item.regions.add(BlurRegion(rect = expanded, type = currentBlurType, intensity = currentIntensity))
            }
        } catch (t: Throwable) {
            item.errorMessage = "人脸识别失败: ${t.localizedMessage}"
        } finally {
            item.isProcessing = false
        }
    }

    fun processedBitmap(item: ImageItem): Bitmap =
        ImageProcessor.apply(item.bitmap, item.regions, rs)

    fun exportSelected(onDone: (Uri?) -> Unit) {
        val item = selectedItem ?: return
        viewModelScope.launch {
            val uri = withContext(Dispatchers.IO) {
                val out = processedBitmap(item)
                FileStore.saveToPictures(
                    getApplication<Application>().applicationContext,
                    out,
                    item.displayName
                )
            }
            onDone(uri)
        }
    }

    fun addRegion(item: ImageItem, rect: RectF) {
        item.regions.add(BlurRegion(rect = rect, type = currentBlurType, intensity = currentIntensity))
    }

    fun removeRegion(item: ImageItem, region: BlurRegion) {
        item.regions.remove(region)
    }

    fun moveRegion(item: ImageItem, regionId: UUID, rect: RectF) {
        val index = item.regions.indexOfFirst { it.id == regionId }
        if (index >= 0) {
            item.regions[index] = item.regions[index].copy(rect = RectF(rect))
        }
    }

    fun clearRegions(item: ImageItem) { item.regions.clear() }

    fun removeItem(item: ImageItem) {
        items.remove(item)
        if (selectedItemID == item.id) selectedItemID = items.firstOrNull()?.id
    }

    override fun onCleared() {
        super.onCleared()
        @Suppress("DEPRECATION")
        rs.destroy()
    }
}
