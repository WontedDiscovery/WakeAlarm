// WakeAlarmBridge.swift
//
// 把 Flutter 的 MethodChannel（wake_alarm/alarmkit）接到 AlarmKit（iOS 26+ 的系統鬧鐘）。
// 系統鬧鐘會準時響、不受靜音與專注模式影響，並顯示在鎖定畫面與動態島上。
// iOS 26 以下，或編譯用的 SDK 沒有 AlarmKit 時，所有方法都回傳「不支援」，App 會改用本地通知。

import Flutter
import UIKit

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
import SwiftUI

/// 每個鬧鐘共用的 metadata（目前不需要額外資料）
@available(iOS 26.0, *)
struct WakeAlarmMetadata: AlarmMetadata, Codable, Hashable {}

/// 響鈴時按「開始運動」會觸發的 intent：只負責把 App 叫到前景，
/// 接下來由 App 內的響鈴頁面（相機挑戰）接手。
@available(iOS 26.0, *)
struct OpenWakeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "開始運動"
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
#endif

final class WakeAlarmBridge {
    /// 在 AppDelegate 的 GeneratedPluginRegistrant.register 之後呼叫一次
    static func register(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "WakeAlarmBridge") else { return }
        let channel = FlutterMethodChannel(
            name: "wake_alarm/alarmkit",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            WakeAlarmBridge.handle(call, result: result)
        }
    }

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            AlarmKitHandler.handle(call, result: result)
            return
        }
        #endif
        // 不支援的系統：isSupported / requestAuthorization 回 false，其餘直接忽略
        switch call.method {
        case "isSupported", "requestAuthorization":
            result(false)
        default:
            result(nil)
        }
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private enum AlarmKitHandler {
    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]

        switch call.method {
        case "isSupported":
            result(true)

        case "requestAuthorization":
            Task {
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    AlarmKitHandler.reply(result, state == .authorized)
                } catch {
                    NSLog("WakeAlarm requestAuthorization failed: \(error)")
                    AlarmKitHandler.reply(result, false)
                }
            }

        case "schedule":
            guard
                let uuid = args["uuid"] as? String,
                let hour = args["hour"] as? Int,
                let minute = args["minute"] as? Int,
                let weekdays = args["weekdays"] as? [Int]
            else {
                result(FlutterError(code: "bad_args", message: "schedule 參數不完整", details: nil))
                return
            }
            Task {
                do {
                    try await AlarmKitHandler.scheduleAlarm(
                        uuid: uuid, hour: hour, minute: minute, weekdays: weekdays
                    )
                    AlarmKitHandler.reply(result, true)
                } catch {
                    NSLog("WakeAlarm schedule failed: \(error)")
                    AlarmKitHandler.reply(result, false)
                }
            }

        case "cancel":
            guard let id = AlarmKitHandler.uuidArg(args) else {
                result(nil)
                return
            }
            Task {
                try? await AlarmManager.shared.cancel(id: id)
                AlarmKitHandler.reply(result, nil)
            }

        case "stop":
            guard let id = AlarmKitHandler.uuidArg(args) else {
                result(nil)
                return
            }
            Task {
                try? await AlarmManager.shared.stop(id: id)
                AlarmKitHandler.reply(result, nil)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func uuidArg(_ args: [String: Any]) -> UUID? {
        guard let s = args["uuid"] as? String else { return nil }
        return UUID(uuidString: s)
    }

    /// 排一個每週重複的鬧鐘（同一個 uuid 要先取消，由 Dart 端負責）
    private static func scheduleAlarm(uuid: String, hour: Int, minute: Int, weekdays: [Int]) async throws {
        guard let id = UUID(uuidString: uuid) else { return }
        let days: [Locale.Weekday] = weekdays.compactMap { AlarmKitHandler.weekday(from: $0) }

        let alert = AlarmPresentation.Alert(
            title: "起床運動",
            stopButton: AlarmButton(text: "停止", textColor: .white, systemImageName: "stop.fill"),
            secondaryButton: AlarmButton(text: "開始運動", textColor: .white, systemImageName: "figure.run"),
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes<WakeAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: WakeAlarmMetadata(),
            tintColor: .orange
        )
        let schedule = Alarm.Schedule.relative(
            .init(time: .init(hour: hour, minute: minute), repeats: .weekly(days))
        )
        let configuration = AlarmManager.AlarmConfiguration<WakeAlarmMetadata>.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: OpenWakeAlarmIntent(),
            sound: .default
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    /// Dart 的 DateTime.weekday（1 = 週一 … 7 = 週日）→ Locale.Weekday
    private static func weekday(from value: Int) -> Locale.Weekday? {
        switch value {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        case 7: return .sunday
        default: return nil
        }
    }

    /// FlutterResult 必須在主執行緒回覆
    private static func reply(_ result: @escaping FlutterResult, _ value: Any?) {
        DispatchQueue.main.async { result(value) }
    }
}
#endif
