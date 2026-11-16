import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App 內可以切換的圖示。深色模式下，iOS 18 以上會自動換成黑白版。
class AppIconOption {
  const AppIconOption({
    required this.altName,
    required this.label,
    required this.hi,
    required this.lo,
  });

  /// 替代圖示的名稱（對應 Xcode 的 AppIcon 資源組）；null 代表預設圖示
  final String? altName;
  final String label;

  /// 圖示背景的漸層色（和產生的圖示顏色一致）
  final Color hi;
  final Color lo;
}

const kAppIconOptions = <AppIconOption>[
  AppIconOption(altName: null, label: '橘色', hi: Color(0xFFFF9A5E), lo: Color(0xFFD9461A)),
  AppIconOption(altName: 'AppIconBlue', label: '藍色', hi: Color(0xFF6CB2FF), lo: Color(0xFF1A55C4)),
  AppIconOption(altName: 'AppIconGreen', label: '綠色', hi: Color(0xFF66DDA6), lo: Color(0xFF17875A)),
  AppIconOption(altName: 'AppIconPurple', label: '紫色', hi: Color(0xFFA88BFF), lo: Color(0xFF4B2BC4)),
  AppIconOption(altName: 'AppIconPink', label: '粉紅', hi: Color(0xFFFF86B2), lo: Color(0xFFCC2A62)),
];

/// 和原生橋接（ios_native/WakeAlarmBridge.swift）溝通，讀取與切換 App 圖示
class AppIconKit {
  static const _channel = MethodChannel('wake_alarm/alarmkit');

  /// 目前的替代圖示名稱；null 代表預設圖示
  static Future<String?> current() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('getIcon');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 換成指定的圖示（name 為 null 時回到預設）。回傳是否成功
  static Future<bool> choose(String? name) async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('setIcon', {'name': name});
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// 主題頁裡的「App 圖示」選擇列
class AppIconPicker extends StatefulWidget {
  const AppIconPicker({super.key});

  @override
  State<AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<AppIconPicker> {
  String? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppIconKit.current().then((name) {
      if (mounted) setState(() => _current = name);
    });
  }

  Future<void> _select(AppIconOption option) async {
    if (_busy || option.altName == _current) return;
    setState(() => _busy = true);
    final ok = await AppIconKit.choose(option.altName);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _current = option.altName;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法更換 App 圖示')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final o in kAppIconOptions)
                GestureDetector(
                  onTap: () => _select(o),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [o.hi, o.lo],
                          ),
                          border: Border.all(
                            color: o.altName == _current
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(o.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '深色模式下會自動換成黑白圖示（iOS 18 以上）。換圖示時，iOS 會跳出一次系統提示。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
