import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _cleanupChannel = AndroidNotificationDetails(
    'cleanup_channel',
    'Notificacoes de Limpeza',
    channelDescription: 'Notificacoes sobre limpeza e organizacao de fotos',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );

  static const _notificationDetails = NotificationDetails(
    android: _cleanupChannel,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _notifications.initialize(settings: settings);
    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showCleanupAnalysis({
    required int blurryCount,
    required int duplicatesCount,
    required int screenshotsCount,
    required double estimatedSpaceGB,
  }) async {
    final items = <String>[
      if (blurryCount > 0) '$blurryCount fotos desfocadas',
      if (duplicatesCount > 0) '$duplicatesCount duplicatas',
      if (screenshotsCount > 0) '$screenshotsCount screenshots',
    ];

    if (items.isEmpty) return;

    final body =
        '${items.join(', ')}. Libere ${estimatedSpaceGB.toStringAsFixed(1)}GB!';

    await _show(
      id: 1,
      title: 'Hora de Limpar!',
      body: body,
    );
  }

  Future<void> showStorageAlert({
    required int totalPhotos,
    required double estimatedSpaceGB,
  }) async {
    await _show(
      id: 2,
      title: 'Galeria Cheia!',
      body:
          'Voce tem $totalPhotos fotos. Organize e libere ${estimatedSpaceGB.toStringAsFixed(1)}GB',
    );
  }

  Future<void> showOnThisDay({
    required int yearsAgo,
    required int photoCount,
  }) async {
    final yearText = yearsAgo == 1 ? 'ano' : 'anos';
    final photoText = photoCount == 1 ? 'foto' : 'fotos';

    await _show(
      id: 3,
      title: 'Memorias de $yearsAgo $yearText atras',
      body: 'Voce tem $photoCount $photoText para revisar',
    );
  }

  Future<void> showOldPhotosReminder({
    required int year,
    required int photoCount,
  }) async {
    await _show(
      id: 4,
      title: 'Fotos Antigas',
      body: 'Voce tem $photoCount fotos de $year que nunca foram organizadas',
    );
  }

  Future<void> scheduleWeeklyCleanup() async {
    await _notifications.zonedSchedule(
      id: 100,
      title: '🧹 Bora dar aquela organizada?',
      body: 'Sua galeria ta pedindo uma limpeza! Que tal dar uma olhada?',
      scheduledDate: _nextWeekday(DateTime.monday, 10),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_cleanup',
          'Limpeza Semanal',
          channelDescription:
              'Notificacoes semanais para limpeza de galeria',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleOnThisDayDaily() async {
    await _notifications.zonedSchedule(
      id: 101,
      title: '📸 Neste Dia',
      body: 'Olha so que memorias legais de anos atras! Vem relembrar',
      scheduledDate: _nextInstanceOfTime(9, 0),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'on_this_day',
          'Neste Dia',
          channelDescription: 'Notificacoes diarias de memorias',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails,
    );
  }

  tz.TZDateTime _nextWeekday(int day, int hour) {
    var scheduledDate = _nextInstanceOfTime(hour, 0);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id: id);
  }

  Future<void> scheduleRecurringNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final isScheduled = prefs.getBool('notifications_scheduled') ?? false;

    if (!isScheduled) {
      await scheduleWeeklyCleanup();
      await scheduleOnThisDayDaily();
      await prefs.setBool('notifications_scheduled', true);
    }
  }
}
