package com.newdawn.soi.audio

import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaRecorder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class NativeRecorderManager(
    private val activity: FlutterActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "native_recorder")

    private var recorder: MediaRecorder? = null
    private var currentPath: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestMicrophonePermission" -> requestMicrophonePermission(result)
            "startRecording" -> startRecording(call, result)
            "stopRecording" -> stopRecording(result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_MIC) {
            return false
        }
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        val granted =
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.RECORD_AUDIO,
            ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.RECORD_AUDIO),
            REQUEST_CODE_MIC,
        )
    }

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        if (filePath.isNullOrEmpty()) {
            result.error("invalid_args", "filePath is required", null)
            return
        }
        try {
            stopRecorderIfNeeded()
            val file = File(filePath)
            if (file.parentFile != null && !file.parentFile!!.exists()) {
                file.parentFile!!.mkdirs()
            }
            val mediaRecorder = MediaRecorder()
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioSamplingRate(44100)
            mediaRecorder.setAudioEncodingBitRate(128000)
            mediaRecorder.setOutputFile(file.absolutePath)
            mediaRecorder.prepare()
            mediaRecorder.start()

            recorder = mediaRecorder
            currentPath = file.absolutePath
            result.success(currentPath)
        } catch (e: Exception) {
            stopRecorderIfNeeded()
            result.error("start_failed", "Failed to start recording: ${e.message}", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        val path = currentPath
        if (recorder == null) {
            result.success(path)
            return
        }
        try {
            recorder?.stop()
        } catch (_: Exception) {
        } finally {
            stopRecorderIfNeeded()
        }
        result.success(path)
    }

    private fun stopRecorderIfNeeded() {
        try {
            recorder?.release()
        } catch (_: Exception) {
        } finally {
            recorder = null
        }
    }

    companion object {
        private const val REQUEST_CODE_MIC = 5102
    }
}
