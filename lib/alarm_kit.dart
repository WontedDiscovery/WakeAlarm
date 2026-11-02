import 'dart:io';

import 'package:flutter/services.dart';

/// 系統鬧鐘（AlarmKit，iOS 26+）的 Flutter 端介面。
/// 原生實作在 ios/Runner/WakeAlarmBridge.swift；不支援時所有方法都會安全地回傳預設值，
/// 呼叫端會改用本地通知。
class AlarmKit {
  static const _channel = MethodChannel('wake_alarm/alarmkit');
  static bool? _supported;

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 這台裝置能不能用系統鬧鐘（需要 iOS 26 以上）
  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    _supported ??= (await _call<bool>('isSupported')) ?? false;
    return _supported!;
  }

  /// 向使用者要鬧鐘權限；已經決定過（允許或拒絕）就不會再跳出視窗
  static Future<bool> requestAuthorization() async =>
      (await _call<bool>('requestAuthorization')) ?? false;

  /// 排一個每週重複的系統鬧鐘。weekdays 採用 DateTime.weekday：1 = 週一 … 7 = 週日。
  /// 同一個 id 要重排前，請先呼叫 cancel。
  static Future<bool> schedule({
    required int id,
    required int hour,
    required int minute,
    required Set<int> weekdays,
  }) async {
    final ok = await _call<bool>('schedule', {
      'uuid': alarmUuid(id),
      'hour': hour,
      'minute': minute,
      'weekdays': weekdays.toList()..sort(),
    });
    return ok ?? false;
  }

  /// 取消系統鬧鐘（不存在也沒關係）
  static Future<void> cancel(int id) async {
    await _call<dynamic>('cancel', {'uuid': alarmUuid(id)});
  }

  /// 停止正在響的系統鬧鐘
  static Future<void> stop(int id) async {
    await _call<dynamic>('stop', {'uuid': alarmUuid(id)});
  }
}

/// 鬧鐘 id → 固定的 UUID：同一個鬧鐘永遠對應到同一個系統鬧鐘
String alarmUuid(int id) => '00000000-0000-4000-8000-${id.toRadixString(16).padLeft(12, '0')}';
