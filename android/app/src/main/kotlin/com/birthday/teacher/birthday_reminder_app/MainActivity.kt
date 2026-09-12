package com.birthday.teacher.birthday_reminder_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import androidx.core.app.ActivityCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.birthday.teacher/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleDailyWorker" -> {
                    val hour = call.argument<Int>("hour") ?: 8
                    val minute = call.argument<Int>("minute") ?: 0
                    BootReceiver.scheduleDailyBirthdayWorker(applicationContext, hour, minute)
                    result.success("Daily birthday worker scheduled for $hour:$minute AM/PM")
                }
                "cancelDailyWorker" -> {
                    WorkManager.getInstance(applicationContext).cancelUniqueWork("TeacherDailyBirthdayWorker")
                    result.success("Daily birthday worker cancelled")
                }
                "triggerTestNotification" -> {
                    val customTitle = call.argument<String>("title") ?: "🎂 Teacher's Birthday Alert"
                    val customMessage = call.argument<String>("message") ?: "Sample student birthday notification test"
                    showTestNotification(customTitle, customMessage)
                    result.success("Test notification fired successfully")
                }
                "notifyBirthdayStudents" -> {
                    val names = call.argument<List<String>>("names") ?: emptyList()
                    val details = call.argument<List<String>>("details") ?: emptyList()
                    if (names.isNotEmpty()) {
                        showStudentBirthdayNotification(names, details)
                        result.success("Notification displayed for ${names.size} students")
                    } else {
                        result.success("No students to notify")
                    }
                }
                "checkNotificationPermission" -> {
                    val areNotificationsEnabled = NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()
                    result.success(areNotificationsEnabled)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                    }
                    val areNotificationsEnabled = NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()
                    result.success(areNotificationsEnabled)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showTestNotification(title: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = BirthdayWorker.CHANNEL_ID

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                BirthdayWorker.CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily reminders for student birthdays to help teachers send wishes"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val smallIconRes = resources.getIdentifier("ic_launcher", "mipmap", packageName)
        val icon = if (smallIconRes != 0) smallIconRes else android.R.drawable.ic_dialog_info

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        notificationManager.notify(BirthdayWorker.NOTIFICATION_ID, builder.build())
    }

    private fun showStudentBirthdayNotification(names: List<String>, details: List<String>) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = BirthdayWorker.CHANNEL_ID

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                BirthdayWorker.CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Daily reminders for student birthdays to help teachers send wishes"
                enableVibration(true)
                enableLights(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val count = names.size
        val title = if (count == 1) {
            "🎂 Today is ${names.first()}'s Birthday!"
        } else {
            "🎂 $count Students Celebrating Birthday Today!"
        }

        val namesSummary = names.joinToString(", ")

        val bigText = buildString {
            append("Wish your students on their special day:\n")
            details.forEachIndexed { index, d ->
                append("${index + 1}. $d\n")
            }
            append("\nTap to open the app and send WhatsApp greetings or make a phone call!")
        }

        val smallIconRes = resources.getIdentifier("ic_launcher", "mipmap", packageName)
        val icon = if (smallIconRes != 0) smallIconRes else android.R.drawable.ic_dialog_info

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(icon)
            .setContentTitle(title)
            .setContentText(namesSummary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        notificationManager.notify(BirthdayWorker.NOTIFICATION_ID, builder.build())
    }
}

