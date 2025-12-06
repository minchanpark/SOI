package com.newdawn.soi

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.soi.instagram_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareToInstagramDirect" -> {
                    val text = call.argument<String>("text") ?: ""
                    val success = shareToInstagramDirect(text)
                    result.success(success)
                }
                "isInstagramInstalled" -> {
                    result.success(isInstagramInstalled())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun shareToInstagramDirect(text: String): Boolean {
        return try {
            // 공유용 이미지 생성
            val bitmap = createShareImage()
            val imageUri = saveBitmapAndGetUri(bitmap)
            
            if (imageUri != null) {
                // 이미지와 함께 공유 - Instagram이 친구 선택 화면을 띄움
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "image/*"
                    putExtra(Intent.EXTRA_STREAM, imageUri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                
                // 공유 선택 화면 열기
                startActivity(Intent.createChooser(intent, "공유하기"))
                true
            } else {
                // 이미지 생성 실패 시 텍스트만 공유
                val fallbackIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(fallbackIntent, "공유하기"))
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun createShareImage(): Bitmap {
        val width = 1080
        val height = 1080
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        // 배경색
        canvas.drawColor(Color.parseColor("#1a1a1a"))
        
        // SOI 로고
        val logoPaint = Paint().apply {
            color = Color.WHITE
            textSize = 200f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("SOI", width / 2f, height * 0.4f, logoPaint)
        
        // 초대 메시지
        val messagePaint = Paint().apply {
            color = Color.parseColor("#e0e0e0")
            textSize = 72f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("친구가 되어주세요!", width / 2f, height * 0.55f, messagePaint)
        
        // 링크
        val linkPaint = Paint().apply {
            color = Color.parseColor("#a0a0a0")
            textSize = 54f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        canvas.drawText("soi-sns.web.app", width / 2f, height * 0.7f, linkPaint)
        
        return bitmap
    }

    private fun saveBitmapAndGetUri(bitmap: Bitmap): Uri? {
        return try {
            val cachePath = File(cacheDir, "images")
            cachePath.mkdirs()
            val file = File(cachePath, "soi_invite.png")
            FileOutputStream(file).use { stream ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            }
            FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun isInstagramInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("com.instagram.android", PackageManager.GET_ACTIVITIES)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
}
