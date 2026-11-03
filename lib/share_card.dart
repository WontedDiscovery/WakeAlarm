import 'dart:io';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'core.dart';
import 'themes.dart';

// 今天有沒有完成過挑戰（任一鬧鐘今天的結果是成功）
bool doneTodayOf(Store s) {
  final today = dayKey(DateTime.now());
  return s.results.entries.any((e) => e.value == 'ok' && e.key.contains('|$today|'));
}

// 分享用的卡片：外觀跟著目前的主題（紫霄符影會多一個符字裝飾）
class ShareCardView extends StatelessWidget {
  const ShareCardView({
    super.key,
    required this.streak,
    required this.doneToday,
    this.detail,
  });

  final int streak;
  final bool doneToday;
  final String? detail; // 例如「開合跳 20 下」，不放鬧鐘時間，保護隱私

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decor = decorOf(context);
    final Gradient gradient = decor.header ??
        LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    final now = DateTime.now();
    return Container(
      width: 360,
      height: 480,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          if (decor.talisman)
            Positioned(
              right: -12,
              top: -28,
              child: Text(
                '符',
                style: TextStyle(
                  fontSize: 200,
                  fontWeight: FontWeight.w900,
                  color: (decor.accent ?? Colors.amber).withAlpha(60),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '醒動鬧鐘',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Text(
                streak > 0 ? '天連續完成' : '開始你的第一天',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                doneToday ? '今天完成了挑戰！' : '今天還沒挑戰，起床動一動',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              const Spacer(),
              Text(
                '${now.year}/${now.month}/${now.day}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 分享卡片頁：預覽卡片；按「分享」會把卡片存成 PNG，交給 iOS 分享面板（LINE、iMessage 等）
class ShareCardPage extends StatefulWidget {
  const ShareCardPage({super.key, required this.store, this.detail});
  final Store store;
  final String? detail;

  @override
  State<ShareCardPage> createState() => _ShareCardPageState();
}

class _ShareCardPageState extends State<ShareCardPage> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('無法產生圖片');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wake_alarm_card.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final streak = widget.store.streak;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: streak > 0 ? '我在醒動鬧鐘已經連續 $streak 天完成運動挑戰！' : '我在醒動鬧鐘開始運動挑戰了！',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('分享失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = widget.store.streak;
    final doneToday = doneTodayOf(widget.store);
    return Scaffold(
      appBar: AppBar(title: const Text('分享卡片')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _cardKey,
              child: ShareCardView(streak: streak, doneToday: doneToday, detail: widget.detail),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: const Icon(Icons.ios_share),
              label: const Text('分享'),
            ),
          ],
        ),
      ),
    );
  }
}
