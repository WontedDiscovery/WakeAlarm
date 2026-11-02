import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'alarm_kit.dart';

const windowMinutes = 3; // 響鈴後的挑戰時限
const scheduleDays = 7; // 預先排程的天數
const maxPending = 60; // iOS 最多 64 則待發通知
const dayNames = ['一', '二', '三', '四', '五', '六', '日'];

enum Exercise { jumpingJack, raiseHands, squat }

String exerciseName(Exercise e) => switch (e) {
      Exercise.jumpingJack => '開合跳',
      Exercise.raiseHands => '舉手',
      Exercise.squat => '深蹲',
    };

String hhmm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String daysText(Set<int> days) =>
    days.length == 7 ? '每天' : '週${([...days]..sort()).map((d) => dayNames[d - 1]).join()}';

class Alarm {
  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.days,
    required this.exercise,
    required this.target,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final int hour;
  final int minute;
  final Set<int> days; // DateTime.weekday：1 = 週一 … 7 = 週日
  final Exercise exercise;
  final int target;
  bool enabled;
  final DateTime createdAt;

  int get minutesOfDay => hour * 60 + minute;

  DateTime ringAt(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'days': days.toList(),
        'exercise': exercise.name,
        'target': target,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Alarm.fromJson(Map<String, dynamic> j) => Alarm(
        id: j['id'] as int,
        hour: j['hour'] as int,
        minute: j['minute'] as int,
        days: Set<int>.from(j['days'] as List),
        exercise: Exercise.values.byName(j['exercise'] as String),
        target: j['target'] as int,
        enabled: j['enabled'] as bool,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class Store {
  Store(this.prefs);
  final SharedPreferences prefs;

  List<Alarm> get alarms {
    final raw = prefs.getString('alarms');
    if (raw == null) return [];
    return [for (final e in jsonDecode(raw) as List) Alarm.fromJson(e as Map<String, dynamic>)];
  }

  Future<void> saveAlarms(List<Alarm> list) =>
      prefs.setString('alarms', jsonEncode([for (final a in list) a.toJson()]));

  // 紀錄格式："鬧鐘id|yyyy-mm-dd" → "ok" 或 "fail"
  Map<String, String> get results {
    final raw = prefs.getString('results');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveResults(Map<String, String> r) => prefs.setString('results', jsonEncode(r));

  int get streak => prefs.getInt('streak') ?? 0;
  Future<void> saveStreak(int v) => prefs.setInt('streak', v);

  String? get lastScan => prefs.getString('lastScan');
  Future<void> saveLastScan(String v) => prefs.setString('lastScan', v);

  // 深色模式：null = 跟隨系統（預設），true = 深色，false = 淺色
  bool? get darkMode => prefs.getBool('darkMode');
  Future<void> saveDarkMode(bool? v) =>
      v == null ? prefs.remove('darkMode') : prefs.setBool('darkMode', v);

  // 已寫入系統鬧鐘（AlarmKit）的鬧鐘：{鬧鐘id: 排程簽章}，用來判斷哪些需要重排
  Map<String, String> get akSynced {
    final raw = prefs.getString('akSynced');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  Future<void> saveAkSynced(Map<String, String> m) => prefs.setString('akSynced', jsonEncode(m));
}

String keyOf(Alarm a, DateTime day) => '${a.id}|${dayKey(day)}';

// 同一天只有最早的鬧鐘會影響連續天數（規格 11.2）
bool isFirstOfDay(Alarm a, DateTime day, List<Alarm> all) {
  final mins = [for (final b in all) if (b.enabled && b.days.contains(day.weekday)) b.minutesOfDay];
  return mins.isEmpty || mins.reduce((x, y) => x < y ? x : y) == a.minutesOfDay;
}

Future<void> resolve(Store s, Alarm a, DateTime day, bool ok) async {
  final r = s.results;
  final k = keyOf(a, day);
  if (r.containsKey(k)) return;
  r[k] = ok ? 'ok' : 'fail';
  await s.saveResults(r);
  if (isFirstOfDay(a, day, s.alarms)) {
    await s.saveStreak(ok ? s.streak + 1 : 0);
  }
}

// 開過 App 後補記：已過時限、沒有紀錄的響鈴一律記為失敗
Future<void> settleMissed(Store s, DateTime now) async {
  final today = DateTime(now.year, now.month, now.day);
  var day = s.lastScan == null ? today : DateTime.parse(s.lastScan!);
  for (; !day.isAfter(today); day = DateTime(day.year, day.month, day.day + 1)) {
    for (final a in s.alarms) {
      if (!a.enabled || !a.days.contains(day.weekday)) continue;
      final ring = a.ringAt(day);
      if (ring.isBefore(a.createdAt)) continue;
      if (now.isBefore(ring.add(const Duration(minutes: windowMinutes)))) continue;
      await resolve(s, a, day, false);
    }
  }
  await s.saveLastScan(dayKey(today));
}

class Ring {
  const Ring(this.alarm, this.day);
  final Alarm alarm;
  final DateTime day;
}

// 目前是否在某次響鈴的挑戰時限內（含昨天跨午夜的鬧鐘）
Ring? findRinging(Store s, DateTime now) {
  final r = s.results;
  for (final a in s.alarms) {
    if (!a.enabled) continue;
    for (final offset in [-1, 0]) {
      final day = DateTime(now.year, now.month, now.day + offset);
      if (!a.days.contains(day.weekday)) continue;
      final ring = a.ringAt(day);
      final end = ring.add(const Duration(minutes: windowMinutes));
      final inWindow = !now.isBefore(ring) && now.isBefore(end) && !ring.isBefore(a.createdAt);
      if (inWindow && !r.containsKey(keyOf(a, day))) return Ring(a, day);
    }
  }
  return null;
}

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz.initializeTimeZones();
  final dynamic zone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(zone is String ? zone : zone.identifier as String));
  await _plugin.initialize(InitializationSettings(iOS: DarwinInitializationSettings()));
}

// 每次都重新排程（啟動、回到前景、儲存或切換鬧鐘時呼叫）
// iOS 26+：交給系統鬧鐘 AlarmKit，準時響、不受靜音與專注模式影響，每週重複由系統負責
// 舊版 iOS，或使用者拒絕鬧鐘權限：退回本地通知（只能播一小段提示音，無法保證準時響鈴）
Future<void> rescheduleAll(Store store, List<Alarm> alarms, DateTime now) async {
  var useAlarmKit = false;
  if (alarms.any((a) => a.enabled) && await AlarmKit.isSupported()) {
    useAlarmKit = await AlarmKit.requestAuthorization();
  }
  if (useAlarmKit) {
    await _plugin.cancelAll();
    await _syncAlarmKit(store, alarms);
    return;
  }
  // 改用通知前，先取消之前寫進系統鬧鐘的，避免同一個鬧鐘響兩次
  for (final id in store.akSynced.keys) {
    await AlarmKit.cancel(int.parse(id));
  }
  await store.saveAkSynced({});
  await _scheduleNotifications(alarms, now);
}

// 只重排「內容有變」的鬧鐘；沒變的完全不碰，免得打斷正在響的鬧鐘
Future<void> _syncAlarmKit(Store store, List<Alarm> alarms) async {
  final prev = store.akSynced;
  final byId = {for (final a in alarms) '${a.id}': a};
  final want = {for (final a in alarms.where((a) => a.enabled)) '${a.id}': _akSignature(a)};
  final done = <String, String>{};
  for (final id in <String>{...prev.keys, ...want.keys}) {
    final sig = want[id];
    if (sig != null && sig == prev[id]) {
      done[id] = sig;
      continue;
    }
    await AlarmKit.cancel(int.parse(id)); // 內容改變、已關閉或已刪除：先取消舊的
    if (sig == null) continue;
    final a = byId[id]!;
    if (await AlarmKit.schedule(id: a.id, hour: a.hour, minute: a.minute, weekdays: a.days)) {
      done[id] = sig;
    }
  }
  await store.saveAkSynced(done);
}

String _akSignature(Alarm a) => '${a.hour}:${a.minute}|${([...a.days]..sort()).join(',')}';

// 挑戰結束（成功或時限到）：關掉系統鬧鐘的響鈴
Future<void> silenceAlarm(Alarm a) async {
  if (await AlarmKit.isSupported()) await AlarmKit.stop(a.id);
}

// 通知備援：只排未來 7 天，最多 60 則
Future<void> _scheduleNotifications(List<Alarm> alarms, DateTime now) async {
  await _plugin.cancelAll();
  final jobs = <(DateTime, int, String)>[];
  for (final a in alarms.where((a) => a.enabled)) {
    for (var k = 0; k < scheduleDays; k++) {
      final day = DateTime(now.year, now.month, now.day + k);
      final ring = a.ringAt(day);
      if (!a.days.contains(day.weekday) || !ring.isAfter(now)) continue;
      final body = '完成「${exerciseName(a.exercise)}」${a.target} 下，$windowMinutes 分鐘內起床！';
      jobs.add((ring, a.id * 10 + k, body));
    }
  }
  jobs.sort((x, y) => x.$1.compareTo(y.$1));
  for (final (ring, id, body) in jobs.take(maxPending)) {
    await _plugin.zonedSchedule(
      id,
      '醒動鬧鐘',
      body,
      tz.TZDateTime.from(ring, tz.local),
      NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
