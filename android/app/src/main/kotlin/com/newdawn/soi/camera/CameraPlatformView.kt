package com.newdawn.soi.camera

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.platform.PlatformView

class CameraPlatformView(
    context: Context,
    private val cameraManager: CameraManager,
) : PlatformView {
    private val previewView: PreviewView = PreviewView(context)

    init {
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        cameraManager.attachPreviewView(previewView)
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        cameraManager.detachPreviewView(previewView)
    }
}
