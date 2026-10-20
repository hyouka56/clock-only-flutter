package com.hyouka.clock

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "clock_only/alarm_sound"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDefaultAlarmSoundUri" ->
                    result.success(Settings.System.DEFAULT_ALARM_ALERT_URI.toString())
                else -> result.notImplemented()
            }
        }
    }
}
