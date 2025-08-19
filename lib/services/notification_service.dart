import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Initialize Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Initialize settings
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_reminders', // Channel ID
      'Task Reminders', // Channel name
      description: 'Notifications for task reminders', // Channel description
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<bool> requestPermission() async {
    // Request notification permission using permission_handler
    PermissionStatus status = await Permission.notification.status;
    
    if (status.isDenied) {
      // Request permission
      status = await Permission.notification.request();
    }
    
    // Also request permission through the plugin for compatibility
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
    
    return status.isGranted;
  }

  Future<void> scheduleTaskReminder(String taskId, String taskTitle) async {
    // Schedule a notification 5 hours from now
    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId.hashCode, // Notification ID based on task ID
      'Your Tasks are Incomplete!!',
      'Don\'t forget to complete: $taskTitle',
      tz.TZDateTime.now(tz.local).add(const Duration(hours: 5)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders',
          'Task Reminders',
          channelDescription: 'Notifications for task reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );
    
    // Log for debugging
    debugPrint('Scheduled notification for task: $taskTitle (ID: $taskId) in 5 hours');
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await flutterLocalNotificationsPlugin.cancel(taskId.hashCode);
    debugPrint('Cancelled notification for task ID: $taskId');
  }
  
  
}