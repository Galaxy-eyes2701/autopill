// lib/core/services/notification_service.dart
//
// pubspec.yaml — thêm:
//   flutter_local_notifications: ^17.2.0
//   timezone: ^0.9.4
//
// AndroidManifest.xml — thêm trong <manifest>:
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//   <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
//   <uses-permission android:name="android.permission.VIBRATE"/>
//   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:typed_data';

// ─── Keys SharedPreferences ───────────────────────────────────────────────────
class NotifPrefsKeys {
  static const soundEnabled     = 'notif_sound_enabled';
  static const vibrationEnabled = 'notif_vibration_enabled';
  static const volume           = 'notif_volume';
  static const soundAsset       = 'notif_sound_asset';
}

// ─── Model âm thanh ───────────────────────────────────────────────────────────
class NotifSound {
  final String name;
  final String asset;
  final String emoji;
  const NotifSound({required this.name, required this.asset, required this.emoji});
}

const List<NotifSound> kNotifSounds = [
  NotifSound(name: 'Mặc định hệ thống', asset: 'default', emoji: '🔔'),
  NotifSound(name: 'Nhẹ nhàng',         asset: 'gentle',  emoji: '🎵'),
  NotifSound(name: 'Chuông y tế',        asset: 'medical', emoji: '🏥'),
  NotifSound(name: 'Tiếng chuông',       asset: 'chime',   emoji: '🎐'),
  NotifSound(name: 'Nhắc nhở nhẹ',      asset: 'soft',    emoji: '🌸'),
];

// ─── Prefs model ──────────────────────────────────────────────────────────────
class NotifPrefs {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final double volume;
  final String soundAsset;

  const NotifPrefs({
    this.soundEnabled     = true,
    this.vibrationEnabled = true,
    this.volume           = 0.8,
    this.soundAsset       = 'default',
  });

  NotifPrefs copyWith({
    bool?   soundEnabled,
    bool?   vibrationEnabled,
    double? volume,
    String? soundAsset,
  }) => NotifPrefs(
    soundEnabled:     soundEnabled     ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    volume:           volume           ?? this.volume,
    soundAsset:       soundAsset       ?? this.soundAsset,
  );
}

// ─── Global navigatorKey ──────────────────────────────────────────────────────
final GlobalKey<NavigatorState> autopillNavigatorKey =
GlobalKey<NavigatorState>();

// ─── Background tap handler (top-level, bắt buộc) ────────────────────────────
@pragma('vm:entry-point')
void onBackgroundNotificationTap(NotificationResponse response) {
  debugPrint('[AutoPill] BG tap: ${response.payload}');
}

// ─── NotificationService ──────────────────────────────────────────────────────
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Callback điều hướng về home — đăng ký từ main.dart
  void Function(String? payload)? _onTapCallback;
  void setOnTapCallback(void Function(String? payload) cb) {
    _onTapCallback = cb;
  }

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse:          _onTap,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationTap,
    );

    // Xin quyền POST_NOTIFICATIONS (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ── Kiểm tra & xin quyền exact alarm (Android 12+) ───────────────────────
  // Trả về true nếu được cấp quyền hoặc không cần (Android < 12)
  Future<bool> requestExactAlarmPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    // Kiểm tra xem đã có quyền chưa
    final granted =
        await androidImpl.requestExactAlarmsPermission() ?? false;
    return granted;
  }

  // ── Foreground tap ────────────────────────────────────────────────────────
  void _onTap(NotificationResponse response) {
    debugPrint('[AutoPill] Notification tapped: ${response.payload}');
    _onTapCallback?.call(response.payload);
  }

  // ── Load / Save prefs ─────────────────────────────────────────────────────
  Future<NotifPrefs> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    return NotifPrefs(
      soundEnabled:     p.getBool(NotifPrefsKeys.soundEnabled)     ?? true,
      vibrationEnabled: p.getBool(NotifPrefsKeys.vibrationEnabled)  ?? true,
      volume:           p.getDouble(NotifPrefsKeys.volume)          ?? 0.8,
      soundAsset:       p.getString(NotifPrefsKeys.soundAsset)      ?? 'default',
    );
  }

  Future<void> savePrefs(NotifPrefs prefs) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(NotifPrefsKeys.soundEnabled,     prefs.soundEnabled);
    await p.setBool(NotifPrefsKeys.vibrationEnabled,  prefs.vibrationEnabled);
    await p.setDouble(NotifPrefsKeys.volume,          prefs.volume);
    await p.setString(NotifPrefsKeys.soundAsset,      prefs.soundAsset);
  }

  // ── Build AndroidNotificationDetails ──────────────────────────────────────
  AndroidNotificationDetails _buildAndroidDetails(
      NotifPrefs prefs, {
        String channelId   = 'autopill_medication',
        String channelName = 'Nhắc uống thuốc',
      }) {
    final vibPattern = Int64List.fromList([0, 500, 300, 500, 300, 500]);

    if (prefs.soundEnabled) {
      final soundSrc = prefs.soundAsset == 'default'
          ? null
          : UriAndroidNotificationSound(
          'android.resource://com.yourapp.autopill/raw/${prefs.soundAsset}');
      return AndroidNotificationDetails(
        channelId, channelName,
        channelDescription: 'Nhắc nhở uống thuốc đúng giờ',
        importance:      Importance.high,
        priority:        Priority.high,
        sound:           soundSrc,
        playSound:       true,
        enableVibration: prefs.vibrationEnabled,
        vibrationPattern: prefs.vibrationEnabled ? vibPattern : null,
      );
    } else {
      return AndroidNotificationDetails(
        '${channelId}_silent', '$channelName (Im lặng)',
        channelDescription: 'Thông báo im lặng từ AutoPill',
        importance:      Importance.high,
        priority:        Priority.high,
        playSound:       false,
        enableVibration: prefs.vibrationEnabled,
        vibrationPattern: prefs.vibrationEnabled ? vibPattern : null,
      );
    }
  }

  // ── Hiển thị thông báo ngay lập tức ──────────────────────────────────────
  Future<void> showMedicationReminder({
    required int    id,
    required String medicineName,
    required String time,
    required String dose,
    String?         label,
  }) async {
    await init();
    final prefs   = await loadPrefs();
    final details = NotificationDetails(android: _buildAndroidDetails(prefs));
    final body    = (label != null && label.isNotEmpty) ? '$dose • $label' : dose;
    await _plugin.show(
      id,
      '💊 Đến giờ uống thuốc!',
      '$medicineName — $body lúc $time',
      details,
      payload: 'medication:$id',
    );
  }

  // ── Lên lịch thông báo ───────────────────────────────────────────────────
  // Tự động fallback sang inexact nếu không có quyền exact alarm
  Future<void> scheduleMedicationAt({
    required int      id,
    required String   medicineName,
    required String   time,
    required String   dose,
    String?           label,
    required DateTime scheduledDate,
  }) async {
    await init();
    final prefs   = await loadPrefs();
    final details = NotificationDetails(android: _buildAndroidDetails(prefs));
    final body    = (label != null && label.isNotEmpty) ? '$dose • $label' : dose;
    final tzDate  = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      // Thử dùng exact alarm trước
      await _plugin.zonedSchedule(
        id,
        '💊 Đến giờ uống thuốc!',
        '$medicineName — $body lúc $time',
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'medication:$id',
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        // Fallback: inexact alarm — vẫn bắn thông báo nhưng có thể lệch vài phút
        debugPrint('[AutoPill] Exact alarm not permitted, using inexact');
        await _plugin.zonedSchedule(
          id,
          '💊 Đến giờ uống thuốc!',
          '$medicineName — $body lúc $time',
          tzDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'medication:$id',
        );
      } else {
        rethrow;
      }
    }
  }

  // ── Huỷ thông báo ────────────────────────────────────────────────────────
  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll()    => _plugin.cancelAll();

  // ── Test notification ─────────────────────────────────────────────────────
  Future<void> showTest(NotifPrefs prefs) async {
    await init();
    final details = NotificationDetails(
      android: _buildAndroidDetails(
        prefs,
        channelId:   'autopill_test',
        channelName: 'Thử nghiệm AutoPill',
      ),
    );
    await _plugin.show(9999, '💊 Thử nghiệm thông báo',
        'Đây là thông báo mẫu từ AutoPill', details);
  }
}