package com.example.agapay_rescuers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 🔔 Create notification channel with custom sound (Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

            val soundUri = Uri.parse(
                "android.resource://${applicationContext.packageName}/raw/notification"
            )

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                "high_importance_channel",
                "High Importance Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(soundUri, audioAttributes)
            }

            val notificationManager =
                getSystemService(NotificationManager::class.java)

            notificationManager.createNotificationChannel(channel)
        }
    }
}
