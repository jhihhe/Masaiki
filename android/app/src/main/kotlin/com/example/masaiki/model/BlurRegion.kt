package com.example.masaiki.model

import android.graphics.RectF
import java.util.UUID

enum class BlurType(val displayName: String) {
    MOSAIC("马赛克"),
    GAUSSIAN("高斯模糊")
}

data class BlurRegion(
    val id: UUID = UUID.randomUUID(),
    val rect: RectF,
    val type: BlurType,
    val intensity: Float // 0.1f ... 1.0f
)
