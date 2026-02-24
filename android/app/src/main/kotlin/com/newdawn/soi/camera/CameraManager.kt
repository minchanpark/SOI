package com.newdawn.soi.camera

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Rational
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.MirrorMode
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.ViewPort
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class CameraManager(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "com.soi.camera")
    private val mainExecutor = ContextCompat.getMainExecutor(activity)
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var previewView: PreviewView? = null
    private var pendingBind = false

    private var camera: Camera? = null
    private var imageCapture: ImageCapture? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    private var isSessionActive = false
    private var lensFacing = CameraSelector.LENS_FACING_BACK

    private var currentVideoPath: String? = null
    private var pendingStopResult: MethodChannel.Result? = null
    private var cancelRequested = false

    init {
        channel.setMethodCallHandler(this)
    }

    fun attachPreviewView(view: PreviewView) {
        previewView = view
        previewView?.implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        if (pendingBind || isSessionActive) {
            previewView?.post {
                ensureCameraProvider {
                    val ok = bindUseCases()
                    pendingBind = !ok
                }
            }
        }
    }

    fun detachPreviewView(view: PreviewView) {
        if (previewView === view) {
            previewView = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepareCamera" -> {
                ensureCameraProvider { result.success(null) }
            }
            "initCamera" -> {
                ensureCameraProvider {
                    val ok = bindUseCases()
                    result.success(ok)
                }
            }
            "isSessionActive" -> result.success(isSessionActive)
            "resumeCamera" -> {
                ensureCameraProvider {
                    val ok = bindUseCases()
                    result.success(ok)
                }
            }
            "pauseCamera" -> {
                cameraProvider?.unbindAll()
                isSessionActive = false
                result.success(null)
            }
            "optimizeCamera" -> {
                result.success(null)
            }
            "setFlash" -> {
                val isOn = call.argument<Boolean>("isOn") == true
                imageCapture?.flashMode =
                    if (isOn) ImageCapture.FLASH_MODE_ON else ImageCapture.FLASH_MODE_OFF
                camera?.cameraControl?.enableTorch(isOn)
                result.success(null)
            }
            "setZoom" -> {
                val zoomValue = call.argument<Double>("zoomValue") ?: 1.0
                camera?.cameraControl?.setZoomRatio(zoomValue.toFloat())
                result.success(null)
            }
            "getAvailableZoomLevels" -> {
                result.success(buildZoomLevels())
            }
            "getZoomRange" -> {
                val zoomState = camera?.cameraInfo?.zoomState?.value
                if (zoomState == null) {
                    result.success(null)
                } else {
                    result.success(
                        mapOf(
                            "minZoom" to zoomState.minZoomRatio.toDouble(),
                            "maxZoom" to zoomState.maxZoomRatio.toDouble(),
                        ),
                    )
                }
            }
            "setBrightness" -> {
                val value = call.argument<Double>("value") ?: 0.0
                setExposureCompensation(value.toFloat())
                result.success(null)
            }
            "supportsLiveSwitch" -> {
                ensureCameraProvider {
                    val provider = cameraProvider
                    if (provider == null) {
                        result.success(false)
                        return@ensureCameraProvider
                    }
                    val hasBack = provider.hasCamera(
                        CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_BACK).build(),
                    )
                    val hasFront = provider.hasCamera(
                        CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_FRONT).build(),
                    )
                    result.success(hasBack && hasFront)
                }
            }
            "takePicture" -> takePicture(result)
            "startVideoRecording" -> startVideoRecording(call, result)
            "stopVideoRecording" -> stopVideoRecording(result)
            "cancelVideoRecording" -> cancelVideoRecording(result)
            "switchCamera" -> {
                lensFacing =
                    if (lensFacing == CameraSelector.LENS_FACING_BACK) {
                        CameraSelector.LENS_FACING_FRONT
                    } else {
                        CameraSelector.LENS_FACING_BACK
                    }
                ensureCameraProvider {
                    bindUseCases()
                    result.success(null)
                }
            }
            "disposeCamera" -> {
                releaseCamera()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureCameraProvider(onReady: () -> Unit) {
        if (cameraProvider != null) {
            onReady()
            return
        }
        if (cameraProviderFuture == null) {
            cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        }
        cameraProviderFuture?.addListener(
            {
                cameraProvider = cameraProviderFuture?.get()
                onReady()
            },
            mainExecutor,
        )
    }

    private fun bindUseCases(): Boolean {
        val provider = cameraProvider ?: return false
        val view = previewView ?: run {
            pendingBind = true
            return false
        }
        if (
            ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) !=
                PackageManager.PERMISSION_GRANTED
        ) {
            isSessionActive = false
            pendingBind = false
            return false
        }
        if (view.width == 0 || view.height == 0) {
            pendingBind = true
            return false
        }

        val preview = Preview.Builder().build()
        preview.setSurfaceProvider(view.surfaceProvider)

        val imageCaptureBuilder =
            ImageCapture.Builder()
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
        try {
            imageCaptureBuilder.setMirrorMode(
                if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                    MirrorMode.MIRROR_MODE_ON
                } else {
                    MirrorMode.MIRROR_MODE_OFF
                },
            )
        } catch (_: UnsupportedOperationException) {
            // Mirror mode not supported on some devices; fall back to default.
        }
        imageCapture = imageCaptureBuilder.build()

        val recorder =
            Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.HD))
                .build()
        val videoCaptureBuilder = VideoCapture.Builder(recorder)
        try {
            videoCaptureBuilder.setMirrorMode(
                if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                    MirrorMode.MIRROR_MODE_ON
                } else {
                    MirrorMode.MIRROR_MODE_OFF
                },
            )
        } catch (_: UnsupportedOperationException) {
            // Mirror mode not supported on some devices; fall back to default.
        }
        videoCapture = videoCaptureBuilder.build()

        val selector = CameraSelector.Builder().requireLensFacing(lensFacing).build()

        val rotation = view.display?.rotation ?: 0
        val viewPort =
            ViewPort.Builder(Rational(view.width, view.height), rotation)
                .setScaleType(ViewPort.FILL_CENTER)
                .build()
        val imageCaptureUseCase = imageCapture ?: return false
        val videoCaptureUseCase = videoCapture ?: return false
        val useCaseGroup =
            UseCaseGroup.Builder()
                .setViewPort(viewPort)
                .addUseCase(preview)
                .addUseCase(imageCaptureUseCase)
                .addUseCase(videoCaptureUseCase)
                .build()

        return try {
            provider.unbindAll()
            camera = provider.bindToLifecycle(activity, selector, useCaseGroup)
            isSessionActive = true
            pendingBind = false
            true
        } catch (_: SecurityException) {
            isSessionActive = false
            pendingBind = false
            false
        }
    }

    private fun takePicture(result: MethodChannel.Result) {
        val capture = imageCapture
        if (capture == null) {
            result.success("")
            return
        }

        val photoFile = createOutputFile(Environment.DIRECTORY_PICTURES, ".jpg")
        val metadata =
            ImageCapture.Metadata().apply {
                if (lensFacing == CameraSelector.LENS_FACING_FRONT) {
                    setReversedHorizontal(true)
                }
            }
        val outputOptions =
            ImageCapture.OutputFileOptions.Builder(photoFile)
                .setMetadata(metadata)
                .build()
        capture.takePicture(
            outputOptions,
            cameraExecutor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    MediaScannerConnection.scanFile(
                        activity,
                        arrayOf(photoFile.absolutePath),
                        arrayOf("image/jpeg"),
                        null,
                    )
                    activity.runOnUiThread { result.success(photoFile.absolutePath) }
                }

                override fun onError(exception: ImageCaptureException) {
                    activity.runOnUiThread { result.success("") }
                }
            },
        )
    }

    private fun startVideoRecording(call: MethodCall, result: MethodChannel.Result) {
        if (recording != null) {
            result.success(true)
            return
        }

        val capture = videoCapture
        if (capture == null) {
            result.success(false)
            return
        }

        val maxDurationMs = call.argument<Int>("maxDurationMs") ?: 0
        val videoFile = createOutputFile(Environment.DIRECTORY_MOVIES, ".mp4")
        currentVideoPath = videoFile.absolutePath
        cancelRequested = false

        val outputOptions = FileOutputOptions.Builder(videoFile).build()
        val pendingRecording = capture.output.prepareRecording(activity, outputOptions)
        val withAudio =
            if (ContextCompat.checkSelfPermission(
                    activity,
                    android.Manifest.permission.RECORD_AUDIO,
                ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                pendingRecording.withAudioEnabled()
            } else {
                pendingRecording
            }

        recording =
            withAudio.start(mainExecutor) { event ->
                when (event) {
                    is VideoRecordEvent.Finalize -> {
                        val path = currentVideoPath
                        val error = event.error
                        val isCanceled = cancelRequested
                        recording?.close()
                        recording = null
                        if (error != VideoRecordEvent.Finalize.ERROR_NONE) {
                            channel.invokeMethod(
                                "onVideoError",
                                mapOf("message" to "Video finalize error: $error"),
                            )
                            pendingStopResult?.success(null)
                            pendingStopResult = null
                        } else if (!isCanceled && path != null) {
                            channel.invokeMethod("onVideoRecorded", mapOf("path" to path))
                            pendingStopResult?.success(path)
                            pendingStopResult = null
                            MediaScannerConnection.scanFile(
                                activity,
                                arrayOf(path),
                                arrayOf("video/mp4"),
                                null,
                            )
                        } else {
                            if (path != null) {
                                File(path).delete()
                            }
                            pendingStopResult?.success(null)
                            pendingStopResult = null
                        }
                    }
                }
            }

        if (maxDurationMs > 0) {
            mainHandler.postDelayed(
                {
                    if (recording != null) {
                        recording?.stop()
                    }
                },
                maxDurationMs.toLong(),
            )
        }

        result.success(true)
    }

    private fun stopVideoRecording(result: MethodChannel.Result) {
        if (recording == null) {
            result.success(null)
            return
        }
        pendingStopResult = result
        recording?.stop()
    }

    private fun cancelVideoRecording(result: MethodChannel.Result) {
        if (recording == null) {
            result.success(false)
            return
        }
        cancelRequested = true
        recording?.stop()
        result.success(true)
    }

    private fun buildZoomLevels(): List<Double> {
        val zoomState = camera?.cameraInfo?.zoomState?.value
        if (zoomState == null) {
            return listOf(1.0)
        }
        val min = zoomState.minZoomRatio.toDouble()
        val max = zoomState.maxZoomRatio.toDouble()
        if (max <= 1.0) {
            return listOf(1.0)
        }
        val levels = mutableListOf<Double>()
        val start = if (min <= 1.0) 1.0 else min
        levels.add(start)
        val maxInt = max.toInt()
        for (i in 2..maxInt) {
            levels.add(i.toDouble())
        }
        if (!levels.contains(max)) {
            levels.add(max)
        }
        return levels.distinct().sorted()
    }

    private fun setExposureCompensation(value: Float) {
        val cam = camera ?: return
        val state = cam.cameraInfo.exposureState
        if (!state.isExposureCompensationSupported) {
            return
        }
        val min = state.exposureCompensationRange.lower
        val max = state.exposureCompensationRange.upper
        val clamped = value.coerceIn(-1.0f, 1.0f)
        val target =
            ((clamped + 1.0f) / 2.0f * (max - min) + min).roundToInt()
        cam.cameraControl.setExposureCompensationIndex(target)
    }

    private fun createOutputFile(directoryType: String, extension: String): File {
        val baseDir = activity.getExternalFilesDir(directoryType) ?: activity.cacheDir
        if (!baseDir.exists()) {
            baseDir.mkdirs()
        }
        val fileName = "soi_${System.currentTimeMillis()}$extension"
        return File(baseDir, fileName)
    }

    private fun releaseCamera() {
        cameraProvider?.unbindAll()
        isSessionActive = false
        recording?.close()
        recording = null
    }
}
