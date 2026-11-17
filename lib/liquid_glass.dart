import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 是否使用 iOS 26 的玻璃介面（只有 iOS 26 以上才開啟，其他系統維持原本的樣子）
final bool kLiquidGlass = _isIOS26OrLater();

bool _isIOS26OrLater() {
  if (!Platform.isIOS) return false;
  // 系統版本字串像 "Version 26.0 (Build ...)"，第一個數字就是主版本號
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  final major = int.tryParse(match?.group(0) ?? '') ?? 0;
  return major >= 26;
}

/// 系統導覽列（原生 UITabBar）的高度
const double kNativeTabBarHeight = 64;

/// 頁面底部要留給懸浮導覽列的空間，內容才不會被擋住（只有 iOS 26 會用到）
double pageBottomInset(BuildContext context) => kLiquidGlass
    ? kNativeTabBarHeight + 16 + MediaQuery.viewPaddingOf(context).bottom
    : 0.0;

/// 原生導覽列與 Flutter 之間的事件通道
const _tabChannel = MethodChannel('wake_alarm/tabbar');

/// iOS 26 以上：系統的 UITabBar，會自動套用真正的液態玻璃（折射、模糊）
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.index,
    required this.tint,
    required this.onTap,
    required this.dark,
  });

  final int index;
  final Color tint;
  final ValueChanged<int> onTap;
  final bool dark; // 跟隨 App 自己的深淺色（不是系統）

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  @override
  void initState() {
    super.initState();
    _tabChannel.setMethodCallHandler(_onNativeCall);
  }

  @override
  void dispose() {
    _tabChannel.setMethodCallHandler(null);
    super.dispose();
  }

  // 使用者在原生導覽列點了分頁
  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'tapped' && call.arguments is int) {
      widget.onTap(call.arguments as int);
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 程式改了分頁或強調色時，同步到原生導覽列
    if (oldWidget.index != widget.index) {
      _tabChannel.invokeMethod<void>('select', widget.index);
    }
    if (oldWidget.tint != widget.tint) {
      _tabChannel.invokeMethod<void>('tint', widget.tint.toARGB32());
    }
    if (oldWidget.dark != widget.dark) {
      _tabChannel.invokeMethod<void>('style', widget.dark);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'wake_alarm/glass_tabbar',
      creationParams: <String, dynamic>{
        'index': widget.index,
        'tint': widget.tint.toARGB32(),
        'dark': widget.dark,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}

/// 玻璃面板：模糊背後的內容、半透明染色、細緻的高光邊框與柔和陰影
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.margin,
    this.padding,
    this.tint,
    this.blur = 22,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Colors.white;
    final corners = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: corners,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(dark ? 110 : 40),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: corners,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: corners,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    base.withAlpha(dark ? 70 : 170),
                    base.withAlpha(dark ? 22 : 70),
                  ],
                ),
                border: Border.all(color: base.withAlpha(dark ? 70 : 220)),
              ),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片：iOS 26 以上換成玻璃面板，其他系統維持原本的 Card
class AdaptiveCard extends StatelessWidget {
  const AdaptiveCard({
    super.key,
    required this.child,
    this.color,
    this.shape,
    this.margin,
  });

  final Widget child;
  final Color? color;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (!kLiquidGlass) {
      return Card(color: color, shape: shape, margin: margin, child: child);
    }
    return GlassPanel(
      tint: color,
      margin: margin ?? const EdgeInsets.all(4),
      child: child,
    );
  }
}
