package com.example.masaiki.service

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.renderscript.Allocation
import android.renderscript.Element
import android.renderscript.RenderScript
import android.renderscript.ScriptIntrinsicBlur
import com.example.masaiki.model.BlurRegion
import com.example.masaiki.model.BlurType
import kotlin.math.max

/**
 * Cross-API image processor.
 *
 * - MOSAIC: pixelate the region by downscaling then upscaling with nearest-neighbor.
 * - GAUSSIAN: use RenderScript ScriptIntrinsicBlur for consistent behavior on API 26+.
 *   (RenderScript remains available at runtime on Android 8-13 even though the class
 *   is deprecated; on Android 14+ AGP forwards to the compat runtime.)
 */
object ImageProcessor {

    /** Apply all regions to a copy of [source] and return the result. */
    fun apply(source: Bitmap, regions: List<BlurRegion>, rs: RenderScript?): Bitmap {
        if (regions.isEmpty()) return source
        val output = source.copy(Bitmap.Config.ARGB_8888, /* isMutable = */ true)
        val canvas = Canvas(output)
        for (region in regions) {
            applyRegion(output, canvas, region, rs)
        }
        return output
    }

    private fun applyRegion(target: Bitmap, canvas: Canvas, region: BlurRegion, rs: RenderScript?) {
        val bounds = clampRect(region.rect, target.width, target.height) ?: return
        val cropped = Bitmap.createBitmap(target, bounds.left, bounds.top, bounds.width(), bounds.height())
        val processed = when (region.type) {
            BlurType.MOSAIC   -> pixelate(cropped, region.intensity)
            BlurType.GAUSSIAN -> gaussianBlur(cropped, region.intensity, rs)
        }
        // Paint the processed region back onto the target bitmap.
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_OVER)
        }
        canvas.drawBitmap(processed, null, bounds, paint)
        cropped.recycle()
        if (processed !== cropped) processed.recycle()
    }

    private fun clampRect(rect: RectF, w: Int, h: Int): Rect? {
        val r = Rect(
            rect.left.toInt().coerceIn(0, w),
            rect.top.toInt().coerceIn(0, h),
            rect.right.toInt().coerceIn(0, w),
            rect.bottom.toInt().coerceIn(0, h)
        )
        return if (r.width() < 2 || r.height() < 2) null else r
    }

    // ---------- Mosaic ----------

    private fun pixelate(src: Bitmap, intensity: Float): Bitmap {
        val scale = (4 + intensity * 56).toInt().coerceAtLeast(2) // 4..60 like macOS
        val w = max(1, src.width  / scale)
        val h = max(1, src.height / scale)
        val small = Bitmap.createScaledBitmap(src, w, h, /* filter = */ false)
        val out   = Bitmap.createScaledBitmap(small, src.width, src.height, /* filter = */ false)
        small.recycle()
        return out
    }

    // ---------- Gaussian ----------

    private fun gaussianBlur(src: Bitmap, intensity: Float, rs: RenderScript?): Bitmap {
        // RenderScript radius 上限 25，用两次串联叠加提升不透明感/磨砂厚度。
        val radius = (4 + intensity * 21).coerceIn(1f, 25f)
        val first = if (rs != null) blurWithRenderScript(src, radius, rs) else blurWithPaint(src, radius)
        val second = if (rs != null) blurWithRenderScript(first, radius, rs) else first
        if (second !== first) first.recycle()
        // 强制填充 alpha=255，避免边缘半透明
        val canvas = Canvas(second)
        val paint = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_OVER); color = 0xFF000000.toInt() }
        canvas.drawRect(0f, 0f, second.width.toFloat(), second.height.toFloat(), paint)
        return second
    }

    @Suppress("DEPRECATION")
    private fun blurWithRenderScript(src: Bitmap, radius: Float, rs: RenderScript): Bitmap {
        val output = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val inAlloc  = Allocation.createFromBitmap(rs, src)
        val outAlloc = Allocation.createFromBitmap(rs, output)
        val script = ScriptIntrinsicBlur.create(rs, Element.U8_4(rs))
        script.setRadius(radius)
        script.setInput(inAlloc)
        script.forEach(outAlloc)
        outAlloc.copyTo(output)
        inAlloc.destroy(); outAlloc.destroy(); script.destroy()
        return output
    }

    /** CPU fallback using BlurMaskFilter — visually similar but slower. */
    private fun blurWithPaint(src: Bitmap, radius: Float): Bitmap {
        val output = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            maskFilter = BlurMaskFilter(radius, BlurMaskFilter.Blur.NORMAL)
        }
        Canvas(output).drawBitmap(src, 0f, 0f, paint)
        return output
    }

    // ---------- IO helpers ----------

    fun decodeBounds(bytes: ByteArray): Pair<Int, Int> {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        return opts.outWidth to opts.outHeight
    }
}
