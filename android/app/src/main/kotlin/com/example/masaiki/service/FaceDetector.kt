package com.example.masaiki.service

import android.graphics.Bitmap
import android.graphics.RectF
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * ML Kit-based face detector. Runs entirely on-device using the bundled model.
 * Coordinates are returned in the same top-left pixel space as the input bitmap.
 */
object FaceDetector {

    private val detector by lazy {
        val opts = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setMinFaceSize(0.05f)
            .build()
        FaceDetection.getClient(opts)
    }

    suspend fun detect(bitmap: Bitmap): List<RectF> = suspendCancellableCoroutine { cont ->
        val image = InputImage.fromBitmap(bitmap, /* rotationDegrees = */ 0)
        detector.process(image)
            .addOnSuccessListener { faces ->
                val rects = faces.map { face ->
                    val b = face.boundingBox
                    RectF(b.left.toFloat(), b.top.toFloat(), b.right.toFloat(), b.bottom.toFloat())
                }
                cont.resume(rects)
            }
            .addOnFailureListener { cont.resumeWithException(it) }
    }
}
