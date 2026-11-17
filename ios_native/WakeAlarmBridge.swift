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
    /// 換成指定的替代圖示（name 為 nil 時回到預設圖示）
    private static func setIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard UIApplication.shared.supportsAlternateIcons else {
            result(false)
            return
        }
        let args = (call.arguments as? [String: Any]) ?? [:]
        let name = args["name"] as? String
        UIApplication.shared.setAlternateIconName(name) { error in
            if let error = error {
                NSLog("WakeAlarm setAlternateIconName failed: \(error)")
            }
            DispatchQueue.main.async { result(error == nil) }
        }
    }

    /// 在 AppDelegate 的 GeneratedPluginRegistrant.register 之後呼叫一次
    static func register(with registry: FlutterPluginRegistry) {
        guard let registrar = registry.registrar(forPlugin: "WakeAlarmBridge") else { return }
        // 系統導覽列平台視圖（UITabBar，iOS 26 會自動套用液態玻璃）
        registrar.register(
            GlassTabBarFactory(messenger: registrar.messenger()),
            withId: "wake_alarm/glass_tabbar"
        )
        let channel = FlutterMethodChannel(
            name: "wake_alarm/alarmkit",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            WakeAlarmBridge.handle(call, result: result)
        }
    }

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // 換 App 圖示：iOS 10.3 以上都支援，所以放在 AlarmKit 判斷之前處理
        switch call.method {
        case "getIcon":
            result(UIApplication.shared.alternateIconName)
            return
        case "setIcon":
            setIcon(call, result: result)
            return
        default:
            break
        }
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


// MARK: - 系統導覽列（UITabBar 平台視圖）
// iOS 26 的 UITabBar 會自動套用液態玻璃（真正的折射與模糊）。
// Flutter 端用 UiKitView（viewType: wake_alarm/glass_tabbar）把它嵌進底部版面。

/// 平台視圖工廠：Flutter 每放一個 UiKitView，就建立一個 UITabBar
final class GlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return GlassTabBarView(frame: frame, messenger: messenger, args: args as? [String: Any])
    }
}

/// 系統的 UITabBar，三個分頁：鬧鐘、計時器、碼表
final class GlassTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let bar: UITabBar
    private let channel: FlutterMethodChannel

    init(frame: CGRect, messenger: FlutterBinaryMessenger, args: [String: Any]?) {
        bar = UITabBar(frame: frame)
        channel = FlutterMethodChannel(name: "wake_alarm/tabbar", binaryMessenger: messenger)
        super.init()

        bar.items = [
            UITabBarItem(title: "鬧鐘", image: UIImage(systemName: "alarm"), tag: 0),
            UITabBarItem(title: "計時器", image: UIImage(systemName: "timer"), tag: 1),
            UITabBarItem(title: "碼表", image: UIImage(systemName: "stopwatch"), tag: 2),
        ]
        bar.delegate = self
        applyTint((args?["tint"] as? Int))
        applyStyle(args?["dark"] as? Bool)
        selectTab((args?["index"] as? Int) ?? 0)

        // Flutter 端的指令：切換分頁、改變強調色
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            switch call.method {
            case "select":
                self.selectTab((call.arguments as? Int) ?? 0)
                result(nil)
            case "tint":
                self.applyTint(call.arguments as? Int)
                result(nil)
            case "style":
                self.applyStyle(call.arguments as? Bool)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView {
        return bar
    }

    // 使用者點了分頁（程式切換不會觸發這裡）：通知 Flutter 切換內容
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        channel.invokeMethod("tapped", arguments: item.tag)
    }

    private func selectTab(_ index: Int) {
        guard let items = bar.items, items.indices.contains(index) else { return }
        bar.selectedItem = items[index]
    }

    // 讓原生導覽列跟著 App 的深淺色（nil = 跟隨系統）
    private func applyStyle(_ dark: Bool?) {
        guard let dark = dark else { return }
        bar.overrideUserInterfaceStyle = dark ? .dark : .light
    }

    private func applyTint(_ argb: Int?) {
        guard let argb = argb else { return }
        bar.tintColor = UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: 1
        )
    }
}
