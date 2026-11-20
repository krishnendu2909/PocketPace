
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  static const int monthlyBackupNotificationId = 500;

  Future<void> initialize() async {
  if (_isInitialized) return;

  tz_data.initializeTimeZones();

  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  String timezoneName = timezoneInfo.identifier;

// Android may return the older India timezone alias.
if (timezoneName == 'Asia/Calcutta') {
  timezoneName = 'Asia/Kolkata';
}
  tz.setLocalLocation(
    tz.getLocation(timezoneName),
  );

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await _notifications.initialize(
    settings: settings,
  );

  _isInitialized = true;
}

  Future<bool> requestPermission() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    final granted =
        await androidPlugin.requestNotificationsPermission();

    return granted ?? false;
  }
  Future<List<PendingNotificationRequest>>
    getPendingNotifications() async {
  await initialize();
  return _notifications.pendingNotificationRequests();
}

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pocketpace_alerts',
      'PocketPace Alerts',
      channelDescription: 'Budget and spending notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  /// Schedules a reminder on the first day of every month at 10 AM.
  Future<void> scheduleMonthlyBackupReminder() async {
    await initialize();

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      1,
      10,
    );

    // If this month's reminder time has passed, schedule next month.
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        1,
        10,
      );
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pocketpace_backup_reminders',
      'Backup Reminders',
      channelDescription: 'Monthly reminders to back up PocketPace data',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      id: monthlyBackupNotificationId,
      title: 'Time to back up PocketPace!',
      body: 'Create a backup to keep your financial data safe.',
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelMonthlyBackupReminder() async {
    await _notifications.cancel(
      id: monthlyBackupNotificationId,
    );
  }

  Future<void> showTestNotification() async {
    await showNotification(
      id: 1,
      title: 'PocketPace is ready!',
      body: 'Your budget notifications are now configured.',
    );
  }
}
