import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 是否使用 iOS 26 的玻璃介面（只有 iOS 26 以上才開啟，其他系統維持原本的樣子）
final bool kLiquidGlass = _isIOS26OrLater();

bool _isIOS26OrLater() {
  if (!Platform.isIOS) return false;
  // 系統版本字串像 "Version 26.0 (Build ...)"，第一個數字就是主版本號
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  final major = int.tryParse(match?.group(0) ?? '') ?? 0;
  return major >= 26;
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
