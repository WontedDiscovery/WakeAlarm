import 'package:flutter/material.dart';

import 'core.dart';

// ── 主題定義 ────────────────────────────────────────────────
// seed = 主色；accent = 次要色；accent2 = 第三色（金色強調）
// 有 art 的是「圖片主題」：背景圖 + 標題列漸層 + 金色強調
class AppThemePreset {
  const AppThemePreset({
    required this.id,
    required this.name,
    required this.seed,
    this.accent,
    this.accent2,
    this.headerEnd,
    this.art,
  });

  final String id;
  final String name;
  final Color seed;
  final Color? accent;
  final Color? accent2;
  final Color? headerEnd; // 圖片主題標題列漸層的終點色
  final String? art; // 背景圖（asset 路徑）
}

const kThemePresets = <AppThemePreset>[
  AppThemePreset(id: 'orange', name: '經典橘', seed: Colors.deepOrange),
  AppThemePreset(id: 'ocean', name: '海洋藍', seed: Color(0xFF0277BD), accent: Color(0xFF26C6DA)),
  AppThemePreset(id: 'forest', name: '森林綠', seed: Color(0xFF2E7D32), accent: Color(0xFFAED581)),
  AppThemePreset(id: 'sakura', name: '櫻花粉', seed: Color(0xFFD81B60), accent: Color(0xFFF8BBD0)),
  AppThemePreset(id: 'lavender', name: '薰衣草紫', seed: Color(0xFF7E57C2), accent: Color(0xFFB39DDB)),
  AppThemePreset(id: 'sunrise', name: '晨曦金', seed: Color(0xFFF9A825), accent: Color(0xFFFF8F00)),
  AppThemePreset(id: 'graphite', name: '石墨灰', seed: Color(0xFF546E7A), accent: Color(0xFF90A4AE)),
  AppThemePreset(id: 'midnight', name: '午夜藍金', seed: Color(0xFF1A237E), accent: Color(0xFFFFD54F)),
  AppThemePreset(
    id: 'talisman',
    name: '紫霄符影',
    seed: Color(0xFF7A6BB8), // 髮色：紫
    accent: Color(0xFF3DB3C2), // 裙擺：青綠
    accent2: Color(0xFFD9AE5B), // 飾品與符紙：金
    headerEnd: Color(0xFF2E3A6B), // 衣襬：深藍
    art: 'assets/talisman_bg.jpg',
  ),
];

// ── 配色 ────────────────────────────────────────────────────

// 用 fromSeed 產生完整的 Material 3 配色，再換上次要色與第三色
ColorScheme schemeFor(AppThemePreset p, Brightness b) {
  final base = ColorScheme.fromSeed(seedColor: p.seed, brightness: b);
  final s = p.accent;
  final t = p.accent2;
  return base.copyWith(
    secondary: s,
    onSecondary: s == null ? null : _onColor(s),
    tertiary: t,
    onTertiary: t == null ? null : _onColor(t),
  );
}

// 這個底色上該用深字還是白字（對比度較好的那個）
Color _onColor(Color c) =>
    c.computeLuminance() > 0.18 ? const Color(0xFF1A1F3A) : Colors.white;

ThemeData buildTheme(AppThemePreset p, Brightness b) {
  final scheme = schemeFor(p, b);
  final isArt = p.art != null;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [
      AppDecor(
        art: p.art,
        overlayAlpha: b == Brightness.dark ? 185 : 150,
        header: isArt
            ? LinearGradient(
                colors: [scheme.primary, p.headerEnd ?? scheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        accent: isArt ? p.accent2 : null,
        onAccent: const Color(0xFF1A1F3A),
      ),
    ],
  );
}

// ── 主題的額外裝飾（背景圖、標題列漸層、金色強調）────────────

class AppDecor extends ThemeExtension<AppDecor> {
  const AppDecor({
    this.art,
    this.overlayAlpha = 0,
    this.header,
    this.accent,
    this.onAccent,
  });

  final String? art;
  final int overlayAlpha; // 背景圖上的遮罩透明度（0–255）
  final Gradient? header;
  final Color? accent;
  final Color? onAccent;

  @override
  AppDecor copyWith({
    String? art,
    int? overlayAlpha,
    Gradient? header,
    Color? accent,
    Color? onAccent,
  }) {
    return AppDecor(
      art: art ?? this.art,
      overlayAlpha: overlayAlpha ?? this.overlayAlpha,
      header: header ?? this.header,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppDecor lerp(ThemeExtension<AppDecor>? other, double t) {
    if (other is! AppDecor) return this;
    return t < 0.5 ? this : other;
  }
}

AppDecor decorOf(BuildContext context) =>
    Theme.of(context).extension<AppDecor>() ?? const AppDecor();

// 標題列：圖片主題用漸層，其他主題回傳 null（就是純色）
Widget? appBarHeader(BuildContext context) {
  final header = decorOf(context).header;
  if (header == null) return null;
  return DecoratedBox(decoration: BoxDecoration(gradient: header));
}

// 卡片：圖片主題用半透明，讓背景圖透出來
Color? cardColorOf(BuildContext context) {
  if (decorOf(context).art == null) return null;
  return Theme.of(context).colorScheme.surface.withAlpha(215);
}

// 卡片外框：圖片主題加金色細邊
ShapeBorder cardShapeOf(BuildContext context) {
  final accent = decorOf(context).accent;
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: accent == null ? BorderSide.none : BorderSide(color: accent, width: 1.2),
  );
}

// 頁面內容：圖片主題時在內容後面鋪上背景圖（半透明遮罩，確保文字看得清楚）
class ThemedBackdrop extends StatelessWidget {
  const ThemedBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decor = decorOf(context);
    final art = decor.art;
    if (art == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(art, fit: BoxFit.cover, alignment: const Alignment(0, -0.35)),
        ColoredBox(color: Theme.of(context).colorScheme.surface.withAlpha(decor.overlayAlpha)),
        child,
      ],
    );
  }
}

// ── 目前的選擇與儲存 ────────────────────────────────────────

// 目前的主題＋深色模式設定（App 內所有頁面都跟著它變）
class ThemeChoice {
  const ThemeChoice(this.preset, this.mode);
  final AppThemePreset preset;
  final ThemeMode mode;
}

final appThemeChoice = ValueNotifier<ThemeChoice>(
  ThemeChoice(kThemePresets.first, ThemeMode.system),
);

AppThemePreset presetById(String? id) =>
    kThemePresets.firstWhere((p) => p.id == id, orElse: () => kThemePresets.first);

// 啟動時讀取上次的主題與深色模式
void loadTheme(Store store) {
  final dark = store.darkMode;
  appThemeChoice.value = ThemeChoice(
    presetById(store.prefs.getString('themeId')),
    dark == null ? ThemeMode.system : (dark ? ThemeMode.dark : ThemeMode.light),
  );
}

Future<void> setThemePreset(Store store, AppThemePreset p) async {
  await store.prefs.setString('themeId', p.id);
  appThemeChoice.value = ThemeChoice(p, appThemeChoice.value.mode);
}

Future<void> setDarkMode(Store store, bool dark) async {
  await store.saveDarkMode(dark);
  appThemeChoice.value = ThemeChoice(
    appThemeChoice.value.preset,
    dark ? ThemeMode.dark : ThemeMode.light,
  );
}
