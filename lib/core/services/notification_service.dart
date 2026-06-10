import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPayload {
  final String title;
  final String body;
  final Map<String, dynamic> data;

  NotificationPayload({
    required this.title,
    required this.body,
    required this.data,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  final StreamController<NotificationPayload> _notificationStream =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get notificationStream => _notificationStream.stream;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'agapay_channel',
    'Agapay Notifications',
    description: 'General notifications for Agapay',
    importance: Importance.high,
  );

  Future<String?> _downloadImage(String url, String fileName) async {
    try {
      final dir = await Directory.systemTemp.create();
      final filePath = '${dir.path}/$fileName';

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      debugPrint('Image download error: $e');
      return null;
    }
  }

  Future<String?> init() async {
    try {
      await _fm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: androidInit, iOS: iOSInit);
    await _local.initialize(initSettings);

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _notificationStream.add(
        NotificationPayload(
          title: initialMessage.notification?.title ?? '',
          body: initialMessage.notification?.body ?? '',
          data: initialMessage.data,
        ),
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notif = message.notification;
      if (notif == null) return;

      final title = notif.title ?? '';
      final body = notif.body ?? '';

      _notificationStream.add(
        NotificationPayload(
          title: title,
          body: body,
          data: message.data,
        ),
      );

      String? imageUrl = notif.android?.imageUrl ?? message.data['image'];
      BigPictureStyleInformation? bigPicture;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final imagePath = await _downloadImage(imageUrl, 'notif_image');
        if (imagePath != null) {
          bigPicture = BigPictureStyleInformation(
            FilePathAndroidBitmap(imagePath),
            contentTitle: title,
            summaryText: body,
          );
        }
      }

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        styleInformation: bigPicture,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    });

    // Try to obtain FCM token with retries to handle transient
    // SERVICE_NOT_AVAILABLE from Play Services on first launch.
    final token = await _getTokenWithRetry();
    if (token != null) {
      debugPrint('FCM Token: $token');
    } else {
      debugPrint('FCM Token unavailable after retries');
    }

    // Keep token updated if it refreshes later
    _fm.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
    });

      return token;
    } catch (e) {
      debugPrint('Notification service init failed: $e');
      return null;
    }
  }

  Future<String?> _getTokenWithRetry({int maxAttempts = 5}) async {
    int attempt = 0;
    Duration delay = const Duration(milliseconds: 500);
    while (attempt < maxAttempts) {
      attempt++;
      try {
        final token = await _fm.getToken();
        if (token != null && token.isNotEmpty) return token;
        // If empty, wait and retry
      } catch (e) {
        // Known transient error on Android: SERVICE_NOT_AVAILABLE
        final msg = e.toString();
        if (!(msg.contains('SERVICE_NOT_AVAILABLE') || msg.contains('IOException'))) {
          // Non-transient error, stop trying
          debugPrint('FCM getToken error (non-retryable): $e');
          return null;
        }
        debugPrint('FCM getToken transient error (attempt $attempt): $e');
      }

      await Future.delayed(delay);
      delay *= 2;
    }
    return null;
  }
}
