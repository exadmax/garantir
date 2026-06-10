import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class WarrantyAlertService {
  WarrantyAlertService({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showExpiryAlert({
    required int id,
    required String productName,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'warranty_alerts',
        'Alertas de Garantia',
        channelDescription: 'Notificacoes de vencimento de garantias',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _notifications.show(id, 'Garantia proxima do vencimento', '$productName: $body', details);
  }

  Future<void> scheduleWarrantyAlerts({
    required String productId,
    required String productName,
    required DateTime warrantyEndDate,
  }) async {
    if (kIsWeb) {
      return;
    }

    await initialize();

    final expiryDate = _atNineAm(warrantyEndDate);
    final preExpiryDate = _atNineAm(warrantyEndDate.subtract(const Duration(days: 7)));

    await cancelAlertsForProduct(productId);

    if (preExpiryDate.isAfter(DateTime.now())) {
      await _schedule(
        id: _notificationId(productId, 1),
        title: 'Garantia vencendo',
        body: '$productName vence em 7 dias',
        dateTime: preExpiryDate,
      );
    }

    if (expiryDate.isAfter(DateTime.now())) {
      await _schedule(
        id: _notificationId(productId, 2),
        title: 'Garantia vence hoje',
        body: productName,
        dateTime: expiryDate,
      );
    }
  }

  Future<void> cancelAlertsForProduct(String productId) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await _notifications.cancel(_notificationId(productId, 1));
    await _notifications.cancel(_notificationId(productId, 2));
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'warranty_alerts',
        'Alertas de Garantia',
        channelDescription: 'Notificacoes de vencimento de garantias',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException {
      // Android 14+ pode negar alarmes exatos (SCHEDULE_EXACT_ALARM).
      // Um lembrete de garantia tolera alguns minutos de imprecisão.
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  DateTime _atNineAm(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 9);
  }

  int _notificationId(String productId, int offset) {
    final hash = productId.codeUnits.fold<int>(0, (acc, unit) {
      return (acc * 31 + unit) & 0x7fffffff;
    });
    return hash + offset;
  }
}
