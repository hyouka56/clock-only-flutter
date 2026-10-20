package com.hyouka.clock

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra(AlarmActivity.EXTRA_ALARM_ID, -1)
        val requestCode = intent.getIntExtra(AlarmActivity.EXTRA_REQUEST_CODE, -1)
        val hour = intent.getIntExtra(AlarmActivity.EXTRA_HOUR, 0)
        val minute = intent.getIntExtra(AlarmActivity.EXTRA_MINUTE, 0)
        val repeatDay = intent.getIntExtra(AlarmActivity.EXTRA_REPEAT_DAY, 0)
        val label = intent.getStringExtra(AlarmActivity.EXTRA_LABEL).orEmpty()
        if (alarmId < 0 || requestCode < 0) return

        // Schedule the next weekly occurrence independently of whether the UI can open.
        if (repeatDay in 1..7) {
            ClockAlarmScheduler.scheduleNextOccurrence(
                context, requestCode, alarmId, hour, minute, repeatDay, label
            )
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createAlarmChannel(context, manager)

        val screenIntent = Intent(context, AlarmActivity::class.java).apply {
            action = intent.action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            intent.extras?.let { putExtras(it) }
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, requestCode, screenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setColor(Color.WHITE)
            .setContentTitle(label.ifBlank { "Alarm" })
            .setContentText("Alarm is ringing")
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .build()
        manager.notify(alarmId, notification)
    }

    private fun createAlarmChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            CHANNEL_ID, "Alarms", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Full-screen alerts for alarms you set"
            setSound(sound, audioAttributes)
            enableVibration(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "clock_alarm_alerts"
    }
}
