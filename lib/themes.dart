import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'core.dart';
import 'liquid_glass.dart';

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
    this.artFile,
  });

  final String id;
  final String name;
  final Color seed;
  final Color? accent;
  final Color? accent2;
  final Color? headerEnd; // 圖片主題標題列漸層的終點色
  final String? art; // 背景圖（asset 路徑）
  final String? artFile; // 自訂背景圖（相簿選的，存在 App 資料夾的檔案路徑）
}

const _kTalismanArt = 'assets/talisman_bg.jpg';

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
    art: _kTalismanArt,
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
  final isArt = p.art != null || p.artFile != null;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // iOS 26 以上：標題列透明、按鈕改成膠囊形、浮動按鈕圓角放大
    appBarTheme: kLiquidGlass
        ? AppBarTheme(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0.0,
            scrolledUnderElevation: 0.0,
          )
        : null,
    floatingActionButtonTheme: kLiquidGlass
        ? FloatingActionButtonThemeData(
            elevation: 0.0,
            highlightElevation: 0.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          )
        : null,
    filledButtonTheme: kLiquidGlass
        ? FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder()))
        : null,
    outlinedButtonTheme: kLiquidGlass
        ? OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: const StadiumBorder()))
        : null,
    extensions: [
      AppDecor(
        art: p.art,
        artFile: p.artFile,
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
    this.artFile,
    this.overlayAlpha = 0,
    this.header,
    this.accent,
    this.onAccent,
  });

  final String? art;
  final String? artFile; // 自訂背景圖檔案
  final int overlayAlpha; // 背景圖上的遮罩透明度（0–255）
  final Gradient? header;
  final Color? accent;
  final Color? onAccent;

  // 是否為「紫霄符影」（分享卡片會多一個符字裝飾）
  bool get talisman => art == _kTalismanArt;

  @override
  AppDecor copyWith({
    String? art,
    String? artFile,
    int? overlayAlpha,
    Gradient? header,
    Color? accent,
    Color? onAccent,
  }) {
    return AppDecor(
      art: art ?? this.art,
      artFile: artFile ?? this.artFile,
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
  final gradient = DecoratedBox(decoration: BoxDecoration(gradient: header));
  // iOS 26 以上：標題列背景半透明，讓下面的內容透出來
  return kLiquidGlass ? Opacity(opacity: 0.86, child: gradient) : gradient;
}

// 卡片：圖片主題用半透明，讓背景圖透出來
Color? cardColorOf(BuildContext context) {
  final d = decorOf(context);
  if (d.art == null && d.artFile == null) return null;
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
    final file = decor.artFile;
    if (art == null && file == null) return child;
    final Widget image = file != null
        ? Image.file(
            File(file),
            key: ValueKey(file),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(), // 圖檔不見了就只顯示底色
          )
        : Image.asset(art!, fit: BoxFit.cover, alignment: const Alignment(0, -0.35));
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        ColoredBox(color: Theme.of(context).colorScheme.surface.withAlpha(decor.overlayAlpha)),
        child,
      ],
    );
  }
}

// 主題列表裡的縮圖（自訂背景用）
class CustomThumb extends StatelessWidget {
  const CustomThumb(this.path, {super.key});
  final String path;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          key: ValueKey(path),
          width: 56,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 40, child: Icon(Icons.broken_image)),
        ),
      );
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

// 相簿選的自訂主題（沒有就是 null）
final customPreset = ValueNotifier<AppThemePreset?>(null);

// 啟動時讀取上次的主題與深色模式
Future<void> loadTheme(Store store) async {
  final dark = store.darkMode;
  customPreset.value = await _loadCustom(store);
  final id = store.prefs.getString('themeId');
  final preset = (id == _kCustomId ? customPreset.value : null) ?? presetById(id);
  appThemeChoice.value = ThemeChoice(
    preset,
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

// ── 相簿圖片當背景，介面顏色從圖片自動取色 ──────────────────

const _kCustomId = 'custom';

// 檔名存在 prefs，每次開啟再接上 App 資料夾路徑（iOS 更新後資料夾路徑可能會變）
Future<AppThemePreset?> _loadCustom(Store store) async {
  final name = store.prefs.getString('customBg');
  final seed = store.prefs.getInt('customSeed');
  if (name == null || seed == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/$name';
  if (!File(path).existsSync()) return null;
  return _customPreset(
    path,
    Color(seed),
    Color(store.prefs.getInt('customAccent') ?? seed),
    Color(store.prefs.getInt('customAccent2') ?? seed),
  );
}

AppThemePreset _customPreset(String path, Color seed, Color accent, Color accent2) {
  final hsv = HSVColor.fromColor(seed);
  return AppThemePreset(
    id: _kCustomId,
    name: '自訂圖片',
    seed: seed,
    accent: accent,
    accent2: accent2,
    headerEnd: hsv.withValue((hsv.value * 0.55).clamp(0.0, 1.0).toDouble()).toColor(),
    artFile: path,
  );
}

// 從相簿選一張圖：存進 App 資料夾、取色、立刻套用。使用者取消選圖時回傳 false
Future<bool> pickCustomBackground(Store store) async {
  final x = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 2400,
    imageQuality: 88,
  );
  if (x == null) return false;
  final bytes = await x.readAsBytes();
  final pal = await _paletteOf(bytes);
  final dir = await getApplicationDocumentsDirectory();
  final name = 'custom_bg_${DateTime.now().millisecondsSinceEpoch}.jpg'; // 每次換檔名，避免圖片快取
  final dest = File('${dir.path}/$name');
  await dest.writeAsBytes(bytes, flush: true);
  await _deleteOldBg(store, dir);
  await store.prefs.setString('customBg', name);
  await store.prefs.setInt('customSeed', pal.seed.toARGB32());
  await store.prefs.setInt('customAccent', pal.accent.toARGB32());
  await store.prefs.setInt('customAccent2', pal.accent2.toARGB32());
  final preset = _customPreset(dest.path, pal.seed, pal.accent, pal.accent2);
  customPreset.value = preset;
  await setThemePreset(store, preset);
  return true;
}

// 套用已存的自訂圖片主題
Future<void> useCustomBackground(Store store) async {
  final p = customPreset.value;
  if (p != null) await setThemePreset(store, p);
}

// 移除自訂背景，回到預設主題
Future<void> clearCustomBackground(Store store) async {
  final dir = await getApplicationDocumentsDirectory();
  await _deleteOldBg(store, dir);
  for (final k in ['customBg', 'customSeed', 'customAccent', 'customAccent2']) {
    await store.prefs.remove(k);
  }
  customPreset.value = null;
  if (appThemeChoice.value.preset.id == _kCustomId) {
    await setThemePreset(store, kThemePresets.first);
  } else {
    // 重新指定一次，讓主題頁刷新
    appThemeChoice.value = ThemeChoice(appThemeChoice.value.preset, appThemeChoice.value.mode);
  }
}

Future<void> _deleteOldBg(Store store, Directory dir) async {
  final old = store.prefs.getString('customBg');
  if (old == null) return;
  try {
    final f = File('${dir.path}/$old');
    if (f.existsSync()) await f.delete();
  } catch (_) {}
}

class _Palette {
  const _Palette(this.seed, this.accent, this.accent2);
  final Color seed;
  final Color accent;
  final Color accent2;
}

// 縮小圖片後，把顏色依色相分成 12 組，挑出最多、最鮮明的當主色；
// 再找色相差距夠大的當次要色與第三色。灰階圖片則用藍灰色。
Future<_Palette> _paletteOf(List<int> bytes) async {
  const fallback = _Palette(Color(0xFF546E7A), Color(0xFF90A4AE), Color(0xFFD9AE5B));
  try {
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes), targetWidth: 64);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return fallback;
    const n = 12;
    final weight = List<double>.filled(n, 0);
    final hueSum = List<double>.filled(n, 0);
    final satSum = List<double>.filled(n, 0);
    final valSum = List<double>.filled(n, 0);
    for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
      if (data.getUint8(i + 3) < 128) continue;
      final c = Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
      final hsv = HSVColor.fromColor(c);
      if (hsv.saturation < 0.2 || hsv.value < 0.2 || hsv.value > 0.97) continue; // 略過灰、近黑、近白
      final b = (hsv.hue / (360 / n)).floor() % n;
      final w = hsv.saturation * hsv.saturation + 0.05;
      weight[b] += w;
      hueSum[b] += hsv.hue * w;
      satSum[b] += hsv.saturation * w;
      valSum[b] += hsv.value * w;
    }
    final order = [for (var i = 0; i < n; i++) if (weight[i] > 0) i]
      ..sort((a, b) => weight[b].compareTo(weight[a]));
    if (order.isEmpty) return fallback;
    HSVColor of(int b) =>
        HSVColor.fromAHSV(1, hueSum[b] / weight[b], satSum[b] / weight[b], valSum[b] / weight[b]);
    double gap(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    final main = of(order.first);
    final seed = main
        .withSaturation(main.saturation.clamp(0.45, 0.85).toDouble())
        .withValue(main.value.clamp(0.45, 0.8).toDouble());
    HSVColor? second;
    HSVColor? third;
    for (final b in order.skip(1)) {
      final c = of(b);
      if (gap(c.hue, main.hue) < 45) continue;
      if (second == null) {
        second = c;
      } else if (third == null && gap(c.hue, second.hue) >= 45) {
        third = c;
      }
    }
    // 圖片顏色太單一時，從主色推算
    final sub = second ?? main.withHue((main.hue + 150) % 360);
    final third2 = third ?? main.withHue((main.hue + 35) % 360);
    Color soft(HSVColor c) =>
        c
            .withSaturation(c.saturation.clamp(0.4, 0.8).toDouble())
            .withValue(c.value.clamp(0.7, 0.95).toDouble())
            .toColor();
    return _Palette(seed.toColor(), soft(sub), soft(third2));
  } catch (_) {
    return fallback;
  }
}
