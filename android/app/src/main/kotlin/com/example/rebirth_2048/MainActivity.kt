package com.example.rebirth_2048

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val HAPTIC_CHANNEL = "rebirth_2048/haptics"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HAPTIC_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "evolutionImpact" -> {
                    vibrateForEvolution()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrateForEvolution() {
        val vibrator =
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                ?: return

        if (!vibrator.hasVibrator()) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(
                    50L,
                    VibrationEffect.DEFAULT_AMPLITUDE,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(50L)
        }
    }
}
