package com.example.masaiki.ui

import android.graphics.RectF
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.input.pointer.positionChanged
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.masaiki.AppViewModel
import com.example.masaiki.model.BlurRegion
import com.example.masaiki.model.BlurType
import com.example.masaiki.model.ImageItem
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private enum class EditorGestureMode {
    Idle,
    Selecting,
    Transforming
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MasaikiScreen(vm: AppViewModel) {
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    var deletingThumbnailID by remember { mutableStateOf<java.util.UUID?>(null) }

    val pickImages = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 20)
    ) { uris -> if (uris.isNotEmpty()) vm.importUris(uris) }
    val launchPicker = {
        pickImages.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
    }

    LaunchedEffect(vm.lastError) {
        vm.lastError?.let {
            snackbar.showSnackbar(it)
            vm.lastError = null
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Column {
                        Text("Masaiki", fontWeight = FontWeight.SemiBold)
                        Text("心中有步兵 眼中有骑兵", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                actions = {
                    IconButton(onClick = {
                        vm.exportSelected { uri ->
                            scope.launch {
                                snackbar.showSnackbar(if (uri != null) "已保存到相册 Pictures/Masaiki" else "保存失败")
                            }
                        }
                    }, enabled = vm.selectedItem != null) {
                        Icon(Icons.Filled.Save, contentDescription = "导出")
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = launchPicker) {
                Icon(Icons.Filled.Add, contentDescription = "导入")
            }
        },
        snackbarHost = { SnackbarHost(snackbar) }
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            ToolbarRow(vm)
            Box(Modifier.weight(1f).fillMaxWidth()) {
                val item = vm.selectedItem
                if (item == null) {
                    EmptyState(onPickImages = launchPicker)
                } else {
                    Editor(item, vm)
                }
            }
            if (vm.items.isNotEmpty()) {
                Strip(
                    vm = vm,
                    deletingThumbnailID = deletingThumbnailID,
                    onToggleDeleteMode = { item ->
                        deletingThumbnailID = if (deletingThumbnailID == item.id) null else item.id
                    },
                    onDelete = { item ->
                        vm.removeItem(item)
                        deletingThumbnailID = null
                    },
                    onSelect = { item ->
                        deletingThumbnailID = null
                        vm.select(item.id)
                    }
                )
            }
        }
    }
}

@Composable
private fun ToolbarRow(vm: AppViewModel) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        BlurType.values().forEach { type ->
            FilterChip(
                selected = vm.currentBlurType == type,
                onClick = { vm.currentBlurType = type },
                label = { Text(type.displayName) }
            )
        }
        Slider(
            value = vm.currentIntensity,
            onValueChange = { vm.currentIntensity = it },
            valueRange = 0.1f..1.0f,
            modifier = Modifier.width(140.dp)
        )
        IconButton(onClick = { vm.selectedItem?.let { vm.autoDetectFaces(it) } }, enabled = vm.selectedItem != null) {
            Icon(Icons.Filled.Face, contentDescription = "识别人脸")
        }
        IconButton(onClick = { vm.selectedItem?.let { vm.clearRegions(it) } }, enabled = (vm.selectedItem?.regions?.isNotEmpty() == true)) {
            Icon(Icons.Filled.Delete, contentDescription = "清除")
        }
    }
}

@Composable
private fun EmptyState(onPickImages: () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .padding(24.dp)
            .clickable(onClick = onPickImages),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .background(
                    MaterialTheme.colorScheme.surface,
                    RoundedCornerShape(20.dp)
                )
                .border(
                    1.dp,
                    MaterialTheme.colorScheme.outlineVariant,
                    RoundedCornerShape(20.dp)
                )
                .padding(horizontal = 28.dp, vertical = 32.dp)
        ) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(48.dp), tint = Color.Gray)
            Text("点击这里添加图片", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 18.sp)
            Text("也可以点击右下角按钮导入", color = Color.Gray, fontSize = 14.sp)
        }
    }
}

@Composable
private fun Editor(item: ImageItem, vm: AppViewModel) {
    var containerSize by remember { mutableStateOf(IntSize.Zero) }
    var dragStart by remember { mutableStateOf<Offset?>(null) }
    var dragCurrent by remember { mutableStateOf<Offset?>(null) }
    var zoomScale by remember(item.id) { mutableStateOf(1f) }
    var panOffset by remember(item.id) { mutableStateOf(Offset.Zero) }
    val density = LocalDensity.current

    val regionsSnapshot = item.regions.toList()
    var processedBitmap by remember { mutableStateOf(item.bitmap) }
    
    LaunchedEffect(item.id, regionsSnapshot) {
        processedBitmap = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            vm.processedBitmap(item)
        }
    }

    val bitmap = processedBitmap
    val imageW = bitmap.width.toFloat()
    val imageH = bitmap.height.toFloat()

    val scale = if (containerSize.width == 0 || containerSize.height == 0) 1f
                else min(containerSize.width / imageW, containerSize.height / imageH)
    val displayW = imageW * scale
    val displayH = imageH * scale
    val contentCenter = Offset(displayW / 2f, displayH / 2f)

    fun clampPan(candidate: Offset, targetZoom: Float = zoomScale): Offset {
        if (targetZoom <= 1f) return Offset.Zero
        val maxPanX = kotlin.math.abs(displayW * targetZoom - containerSize.width) / 2f
        val maxPanY = kotlin.math.abs(displayH * targetZoom - containerSize.height) / 2f
        return Offset(
            candidate.x.coerceIn(-maxPanX, maxPanX),
            candidate.y.coerceIn(-maxPanY, maxPanY)
        )
    }

    fun viewPointToImage(point: Offset): Offset {
        val centerX = containerSize.width / 2f
        val centerY = containerSize.height / 2f
        val localX = (point.x - centerX - panOffset.x) / zoomScale
        val localY = (point.y - centerY - panOffset.y) / zoomScale
        val xInImage = localX + displayW / 2f
        val yInImage = localY + displayH / 2f
        return Offset(
            (xInImage / scale).coerceIn(0f, imageW),
            (yInImage / scale).coerceIn(0f, imageH)
        )
    }

    fun moveRegion(regionId: java.util.UUID, viewDelta: Offset) {
        val index = item.regions.indexOfFirst { it.id == regionId }
        if (index < 0) return
        val deltaX = viewDelta.x / scale
        val deltaY = viewDelta.y / scale
        val current = item.regions[index].rect
        val newRect = RectF(
            (current.left + deltaX).coerceIn(0f, imageW - current.width()),
            (current.top + deltaY).coerceIn(0f, imageH - current.height()),
            0f,
            0f
        )
        newRect.right = newRect.left + current.width()
        newRect.bottom = newRect.top + current.height()
        vm.moveRegion(item, regionId, newRect)
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .onGloballyPositioned { containerSize = it.size }
            .clipToBounds()
            .pointerInput(item.id, scale) {
                awaitEachGesture {
                    val firstDown = awaitFirstDown(requireUnconsumed = false)
                    var mode = EditorGestureMode.Idle
                    var selectionOrigin = firstDown.position
                    dragStart = null
                    dragCurrent = null

                    while (true) {
                        val event = awaitPointerEvent()
                        val pressed = event.changes.filter { it.pressed }
                        if (pressed.isEmpty()) break

                        val pointerCount = pressed.size
                        if (pointerCount > 1 || mode == EditorGestureMode.Transforming) {
                            mode = EditorGestureMode.Transforming
                            dragStart = null
                            dragCurrent = null

                            val oldZoom = zoomScale
                            val newZoom = (oldZoom * event.calculateZoom()).coerceIn(1f, 4f)
                            val centroid = event.calculateCentroid(useCurrent = true)
                            val center = Offset(containerSize.width / 2f, containerSize.height / 2f)
                            val focal = centroid - center
                            val pan = event.calculatePan()
                            val updatedPan = if (newZoom <= 1.01f) {
                                Offset.Zero
                            } else {
                                val ratio = newZoom / oldZoom
                                val candidate = Offset(panOffset.x * ratio, panOffset.y * ratio) + pan + focal - Offset(focal.x * ratio, focal.y * ratio)
                                clampPan(candidate, newZoom)
                            }

                            zoomScale = if (newZoom <= 1.01f) 1f else newZoom
                            panOffset = updatedPan
                            event.changes.forEach { if (it.positionChanged()) it.consume() }
                            continue
                        }

                        val change = pressed.first()
                        if (change.isConsumed) continue
                        val delta = change.position - selectionOrigin

                        val moved = delta.getDistance() > viewConfiguration.touchSlop
                        if (mode == EditorGestureMode.Idle && moved) {
                            mode = EditorGestureMode.Selecting
                            dragStart = selectionOrigin
                            dragCurrent = change.position
                        } else if (mode == EditorGestureMode.Selecting) {
                            dragCurrent = change.position
                        }

                        if (mode == EditorGestureMode.Selecting && change.positionChanged()) {
                            change.consume()
                        }
                    }

                    if (mode == EditorGestureMode.Selecting) {
                        val s = dragStart
                        val c = dragCurrent
                        if (s != null && c != null) {
                            val start = viewPointToImage(s)
                            val end = viewPointToImage(c)
                            val l = min(start.x, end.x)
                            val t = min(start.y, end.y)
                            val r = max(start.x, end.x)
                            val b = max(start.y, end.y)
                            val rect = RectF(
                                l.coerceIn(0f, imageW),
                                t.coerceIn(0f, imageH),
                                r.coerceIn(0f, imageW),
                                b.coerceIn(0f, imageH)
                            )
                            if (rect.width() > 8 && rect.height() > 8) {
                                vm.addRegion(item, rect)
                            }
                        }
                    }

                    dragStart = null
                    dragCurrent = null
                }
            }
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .graphicsLayer {
                        scaleX = zoomScale
                        scaleY = zoomScale
                        translationX = panOffset.x
                        translationY = panOffset.y
                        transformOrigin = TransformOrigin.Center
                    }
                    .width(with(density) { displayW.toDp() })
                    .height(with(density) { displayH.toDp() })
            ) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = item.displayName,
                    contentScale = ContentScale.FillBounds,
                    modifier = Modifier.fillMaxSize()
                )

                item.regions.forEach { region ->
                    RegionOverlay(
                        region = region,
                        scale = scale,
                        density = density,
                        onDelete = { vm.removeRegion(item, region) },
                        onMove = { delta -> moveRegion(region.id, delta) }
                    )
                }
            }

            val s = dragStart
            val c = dragCurrent
            if (s != null && c != null) {
                val left = min(s.x, c.x)
                val top = min(s.y, c.y)
                val width = (max(s.x, c.x) - left).coerceAtLeast(0f)
                val height = (max(s.y, c.y) - top).coerceAtLeast(0f)
                Box(
                    Modifier
                        .offset { IntOffset(left.roundToInt(), top.roundToInt()) }
                        .width(with(density) { width.toDp() })
                        .height(with(density) { height.toDp() })
                        .border(2.dp, MaterialTheme.colorScheme.primary)
                )
            }

        if (item.isProcessing) CircularProgressIndicator()
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Strip(
    vm: AppViewModel,
    deletingThumbnailID: java.util.UUID?,
    onToggleDeleteMode: (ImageItem) -> Unit,
    onDelete: (ImageItem) -> Unit,
    onSelect: (ImageItem) -> Unit
) {
    val haptics = LocalHapticFeedback.current
    LazyRow(
        modifier = Modifier.fillMaxWidth().height(84.dp).padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp)
    ) {
        items(vm.items) { item ->
            val selected = item.id == vm.selectedItemID
            val deleting = item.id == deletingThumbnailID
            Box(
                Modifier
                    .size(64.dp)
                    .background(Color.LightGray, RoundedCornerShape(8.dp))
                    .border(2.dp, if (selected) MaterialTheme.colorScheme.primary else Color.Transparent, RoundedCornerShape(8.dp))
                    .combinedClickable(
                        onClick = { onSelect(item) },
                        onLongClick = {
                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                            onToggleDeleteMode(item)
                        }
                    )
            ) {
                Image(
                    bitmap = item.bitmap.asImageBitmap(),
                    contentDescription = item.displayName,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize()
                )

                val scrimAlpha by animateFloatAsState(
                    targetValue = if (deleting) 0.22f else 0f,
                    animationSpec = spring(stiffness = Spring.StiffnessLow),
                    label = "thumb_delete_scrim"
                )
                Box(
                    modifier = Modifier
                        .matchParentSize()
                        .background(Color.Red.copy(alpha = scrimAlpha), RoundedCornerShape(8.dp))
                )

                AnimatedVisibility(
                    visible = deleting,
                    enter = fadeIn() + scaleIn(initialScale = 0.7f),
                    exit = fadeOut() + scaleOut(targetScale = 0.7f),
                    modifier = Modifier.align(Alignment.TopEnd)
                ) {
                    DeleteBadge(
                        modifier = Modifier.offset(x = 8.dp, y = (-8).dp),
                        onDelete = { onDelete(item) }
                    )
                }
            }
            Spacer(Modifier.width(0.dp))
        }
    }
}

@Composable
private fun RegionOverlay(
    region: BlurRegion,
    scale: Float,
    density: androidx.compose.ui.unit.Density,
    onDelete: () -> Unit,
    onMove: (Offset) -> Unit
) {
    var liveOffset by remember(region.id) { mutableStateOf(Offset.Zero) }
    var isDragging by remember(region.id) { mutableStateOf(false) }
    val color = if (region.type == BlurType.MOSAIC) Color.Yellow else Color.Cyan
    val left = region.rect.left * scale
    val top = region.rect.top * scale
    val width = region.rect.width() * scale
    val height = region.rect.height() * scale

    Box(
        modifier = Modifier
            .offset {
                IntOffset(
                    (left + liveOffset.x).roundToInt(),
                    (top + liveOffset.y).roundToInt()
                )
            }
            .width(with(density) { width.toDp() })
            .height(with(density) { height.toDp() })
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(color.copy(alpha = if (isDragging) 0.25f else 0.15f))
                .border(2.dp, color)
                .pointerInput(region.id) {
                    detectDragGestures(
                        onDragStart = { isDragging = true },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            liveOffset += Offset(dragAmount.x, dragAmount.y)
                        },
                        onDragEnd = {
                            onMove(liveOffset)
                            liveOffset = Offset.Zero
                            isDragging = false
                        },
                        onDragCancel = {
                            liveOffset = Offset.Zero
                            isDragging = false
                        }
                    )
                }
        )

        DeleteBadge(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 10.dp, y = (-10).dp),
            onDelete = onDelete
        )
    }
}

@Composable
private fun DeleteBadge(
    modifier: Modifier = Modifier,
    onDelete: () -> Unit
) {
    Box(
        modifier = modifier
            .size(28.dp)
            .background(Color(0xFFE53935), CircleShape)
            .border(2.dp, Color.White, CircleShape)
            .clickable(onClick = onDelete),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            Icons.Filled.Close,
            contentDescription = "删除",
            tint = Color.White,
            modifier = Modifier.size(18.dp)
        )
    }
}
