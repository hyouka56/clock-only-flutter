package com.hyouka.clock

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.util.TypedValue
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : Activity() {
    companion object {
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_REQUEST_CODE = "alarm_request_code"
        const val EXTRA_HOUR = "alarm_hour"
        const val EXTRA_MINUTE = "alarm_minute"
        const val EXTRA_REPEAT_DAY = "alarm_repeat_day"
        const val EXTRA_LABEL = "alarm_label"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var ringtone: Ringtone? = null
    private var currentAlarmId: Int = -1
    private var currentLabel: String = ""
    private lateinit var clockText: TextView
    private lateinit var labelText: TextView
    private val clockTick = object : Runnable {
        override fun run() {
            if (::clockText.isInitialized) clockText.text = SimpleDateFormat("h:mm", Locale.getDefault()).format(Date())
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        configureLockScreen()
        buildAlarmScreen()
        handleAlarmIntent(intent)
        handler.post(clockTick)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmIntent(intent)
    }

    private fun configureLockScreen() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )
    }

    private fun buildAlarmScreen() {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(24), dp(28), dp(24))
            setBackgroundColor(Color.BLACK)
        }
        val eyebrow = TextView(this).apply {
            text = "ALARM"
            setTextColor(Color.LTGRAY)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            letterSpacing = 0.22f
            gravity = Gravity.CENTER
        }
        clockText = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 88f)
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            letterSpacing = -0.04f
            gravity = Gravity.CENTER
            includeFontPadding = false
        }
        labelText = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            gravity = Gravity.CENTER
            maxLines = 2
        }
        val snoozeButton = Button(this).apply {
            text = "SNOOZE · 5 MIN"
            isAllCaps = false
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            backgroundTintList = null
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(32).toFloat()
                setColor(Color.BLACK)
                setStroke(dp(1), Color.rgb(52, 52, 52))
            }
            setOnClickListener { snoozeAlarm() }
        }
        val dismissButton = Button(this).apply {
            text = "DISMISS"
            isAllCaps = false
            setTextColor(Color.BLACK)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            backgroundTintList = null
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(32).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.WHITE)
            }
            setOnClickListener { dismissAlarm() }
        }
        root.addView(eyebrow, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(clockText, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(18) })
        root.addView(labelText, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(20) })
        root.addView(snoozeButton, LinearLayout.LayoutParams(dp(300), dp(60)).apply { topMargin = dp(48) })
        root.addView(dismissButton, LinearLayout.LayoutParams(dp(300), dp(64)).apply { topMargin = dp(12) })
        setContentView(root)
    }

    private fun handleAlarmIntent(alarmIntent: android.content.Intent?) {
        stopRingtone()
        if (alarmIntent == null) return
        val alarmId = alarmIntent.getIntExtra(EXTRA_ALARM_ID, -1)
        currentAlarmId = alarmId
        val label = alarmIntent.getStringExtra(EXTRA_LABEL).orEmpty()
        currentLabel = label
        labelText.text = label.ifBlank { "Alarm is ringing" }
        if (alarmId >= 0) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(alarmId)
        }
        startRingtone()
    }

    private fun startRingtone() {
        val uri = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
            ?: Settings.System.DEFAULT_ALARM_ALERT_URI
        ringtone = RingtoneManager.getRingtone(this, uri)
        ringtone?.setAudioAttributes(AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone?.isLooping = true
        try { ringtone?.play() } catch (_: Exception) { }
    }

    private fun stopRingtone() {
        try { ringtone?.stop() } catch (_: Exception) { }
        ringtone = null
    }

    private fun snoozeAlarm() {
        val scheduled = currentAlarmId >= 0 &&
            ClockAlarmScheduler.scheduleSnooze(this, currentAlarmId, currentLabel)
        if (!scheduled) {
            android.widget.Toast.makeText(
                this, "Enable exact alarm access to snooze", android.widget.Toast.LENGTH_LONG
            ).show()
            return
        }
        dismissAlarm()
    }

    private fun dismissAlarm() {
        stopRingtone()
        if (currentAlarmId >= 0) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(currentAlarmId)
        }
        finishAndRemoveTask()
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        dismissAlarm()
    }

    override fun onDestroy() {
        handler.removeCallbacks(clockTick)
        stopRingtone()
        super.onDestroy()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        )
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
