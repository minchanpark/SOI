package com.newdawn.soi

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import com.newdawn.soi.audio.NativeRecorderManager
import com.newdawn.soi.camera.CameraManager
import com.newdawn.soi.camera.CameraViewFactory

class MainActivity : FlutterActivity() {
    private var cameraManager: CameraManager? = null
    private var recorderManager: NativeRecorderManager? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        cameraManager = CameraManager(this, messenger)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("com.soi.camera", CameraViewFactory(this, cameraManager!!))

        recorderManager = NativeRecorderManager(this, messenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        val handled =
            recorderManager?.onRequestPermissionsResult(requestCode, permissions, grantResults) == true
        if (!handled) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
