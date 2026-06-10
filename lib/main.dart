import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'package:agapay_rescuers/core/services/notification_service.dart';
import 'package:agapay_rescuers/features/auth/auth_wrapper.dart';

/// 🔔 REQUIRED for background / terminated messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Background message received: ${message.messageId}');
  debugPrint('Data: ${message.data}');

  // If there's a notification payload, Android already shows it automatically.
  // Only show local notification for data-only messages.
  if (message.notification != null) {
    debugPrint('Notification payload present - Android handles display');
    return;
  }

  // Data-only message - we need to show notification manually
  String? title = message.data['title'];
  String? body = message.data['body'];

  if (title == null && body == null) {
    debugPrint('No notification content to display');
    return;
  }

  const channel = AndroidNotificationChannel(
    'agapay_channel',
    'Agapay Notifications',
    description: 'General notifications for Agapay',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title ?? 'New Incident',
    body ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
      ),
    ),
  );

  debugPrint('Background notification displayed');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('sos_records');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 REGISTER BACKGROUND HANDLER (MUST BE BEFORE init)
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // 🔔 INITIALIZE NOTIFICATIONS
  NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(), 
    );
  }
}
