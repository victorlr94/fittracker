import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notificación local para el cronómetro de descanso entre series
/// (docs/02-roadmap.md, Fase 1). Se programa con `inexactAllowWhileIdle`
/// a propósito: no requiere el permiso especial de alarmas exactas, y
/// unos segundos de margen no importan para un descanso de gimnasio — el
/// cronómetro visible en pantalla, mientras la app está abierta, sigue
/// siendo la referencia principal.
class RestTimerNotifications {
  RestTimerNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _restTimerNotificationId = 1001;
  static const _channelId = 'rest_timer';

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleRestOver(Duration delay) async {
    await cancel();
    await _plugin.zonedSchedule(
      id: _restTimerNotificationId,
      title: 'Descanso terminado',
      body: 'Hora de la siguiente serie.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Cronómetro de descanso',
          channelDescription: 'Avisa cuando termina el descanso entre series',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> cancel() => _plugin.cancel(id: _restTimerNotificationId);
}
