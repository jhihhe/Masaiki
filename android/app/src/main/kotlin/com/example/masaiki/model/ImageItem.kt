package com.example.masaiki.model

import android.graphics.Bitmap
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.UUID

class ImageItem(
    val id: UUID = UUID.randomUUID(),
    val uri: Uri,
    val displayName: String,
    val bitmap: Bitmap,
    val originalFileSize: Long
) {
    val regions = mutableStateListOf<BlurRegion>()
    var isProcessing by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)
}
