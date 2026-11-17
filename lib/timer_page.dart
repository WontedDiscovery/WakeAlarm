import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core.dart';
import 'liquid_glass.dart';
import 'themes.dart';

enum _Phase { idle, running, paused } // 順序要和 core.dart 的 kTimerRunning 一致

/// 倒數顯示：不足一小時只顯示 分:秒，無條件進位到秒（最後一秒不會提早變成 00:00）
String fmtCountdown(Duration d) {
  final total = (d.inMilliseconds + 999) ~/ 1000;
  final h = total ~/ 3600;
  final m = (total ~/ 60) % 60;
  final s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key, required this.store});

  final Store store;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with WidgetsBindingObserver {
  _Phase _phase = _Phase.idle;
  Duration _picked = const Duration(minutes: 5); // 閒置時設定的時長
  Duration _total = const Duration(minutes: 5); // 這一輪的總時長（畫圓環用）
  Duration _left = const Duration(minutes: 5); // 暫停時剩下的時間
  DateTime? _endAt; // 計時中的結束時間
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _phase != _Phase.running) return;
    if (_remaining == Duration.zero) {
      unawaited(_finish(notify: false)); // 在背景時間就到了，通知早就響過
    } else {
      _startTicker();
      setState(() {});
    }
  }

  // 從 SharedPreferences 讀回上次的狀態（App 被關掉再開也能接著計）
  void _restore() {
    final p = widget.store.prefs;
    _picked = Duration(
        milliseconds: p.getInt(kTimerPicked) ?? const Duration(minutes: 5).inMilliseconds);
    _total = Duration(milliseconds: p.getInt(kTimerTotal) ?? _picked.inMilliseconds);
    _left = Duration(milliseconds: p.getInt(kTimerLeft) ?? _picked.inMilliseconds);
    final idx = p.getInt(kTimerMode) ?? 0;
    _phase = idx == 1 ? _Phase.running : (idx == 2 ? _Phase.paused : _Phase.idle);
    final endMs = p.getInt(kTimerEndAt);
    if (_phase == _Phase.running && endMs != null) {
      _endAt = DateTime.fromMillisecondsSinceEpoch(endMs);
    }
    if (_phase == _Phase.running) {
      if (_remaining == Duration.zero) {
        _phase = _Phase.idle; // 離開期間就已經時間到
        _endAt = null;
        unawaited(_save());
      } else {
        _startTicker();
      }
    }
  }

  // 目前剩下的時間
  Duration get _remaining {
    if (_phase == _Phase.running) {
      final end = _endAt;
      if (end == null) return Duration.zero;
      final d = end.difference(DateTime.now());
      return d.isNegative ? Duration.zero : d;
    }
    if (_phase == _Phase.paused) return _left;
    return _picked;
  }

  Future<void> _save() async {
    final p = widget.store.prefs;
    await p.setInt(kTimerMode, _phase.index);
    await p.setInt(kTimerPicked, _picked.inMilliseconds);
    await p.setInt(kTimerTotal, _total.inMilliseconds);
    await p.setInt(kTimerLeft, _left.inMilliseconds);
    final end = _endAt;
    if (_phase == _Phase.running && end != null) {
      await p.setInt(kTimerEndAt, end.millisecondsSinceEpoch);
    } else {
      await p.remove(kTimerEndAt);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_phase != _Phase.running) return;
      if (_remaining == Duration.zero) {
        unawaited(_finish(notify: true));
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _start() async {
    if (_phase == _Phase.idle) {
      if (_picked == Duration.zero) return;
      _total = _picked;
      _left = _picked;
    }
    final end = DateTime.now().add(_left);
    _endAt = end;
    _phase = _Phase.running;
    _startTicker();
    setState(() {});
    await _save();
    await scheduleTimerNotice(end); // 就算 App 在背景，時間到也會響
  }

  Future<void> _pause() async {
    _left = _remaining;
    _endAt = null;
    _phase = _Phase.paused;
    _ticker?.cancel();
    setState(() {});
    await cancelTimerNotice();
    await _save();
  }

  Future<void> _reset() async {
    _ticker?.cancel();
    _endAt = null;
    _phase = _Phase.idle;
    setState(() {});
    await cancelTimerNotice();
    await _save();
  }

  Future<void> _finish({required bool notify}) async {
    _ticker?.cancel();
    _endAt = null;
    _phase = _Phase.idle;
    await cancelTimerNotice(); // 不再補發通知
    await _save();
    if (!mounted) return;
    setState(() {});
    if (!notify) return;
    unawaited(HapticFeedback.heavyImpact());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('時間到！'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('好')),
        ],
      ),
    );
  }

  void _onPicked(Duration d) {
    setState(() => _picked = d);
    unawaited(_save());
  }

  // 主按鈕：閒置 → 開始、計時中 → 暫停、暫停 → 繼續
  VoidCallback? get _mainAction {
    if (_phase == _Phase.running) return () => unawaited(_pause());
    if (_phase == _Phase.paused) return () => unawaited(_start());
    return _picked == Duration.zero ? null : () => unawaited(_start());
  }

  String get _mainLabel {
    if (_phase == _Phase.running) return '暫停';
    if (_phase == _Phase.paused) return '繼續';
    return '開始';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = decorOf(context).accent ?? scheme.primary;
    final idle = _phase == _Phase.idle;
    final shown = _remaining;
    final total = _total.inMilliseconds;
    final double progress = (idle || total == 0) ? 1.0 : shown.inMilliseconds / total;
    final caption = _phase == _Phase.running
        ? '計時中'
        : (_phase == _Phase.paused ? '已暫停' : '設定時間後按開始');

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: appBarHeader(context),
        title: const Text('計時器'),
      ),
      body: ThemedBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, 24, 0, 24 + pageBottomInset(context)),
            child: Column(
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(240, 240),
                        painter: _RingPainter(
                          progress: progress,
                          color: accent,
                          track: accent.withAlpha(50),
                        ),
                      ),
                      Text(
                        fmtCountdown(shown),
                        style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(caption, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (idle)
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(brightness: Theme.of(context).brightness),
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hms,
                        initialTimerDuration: _picked,
                        onTimerDurationChanged: _onPicked,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: idle ? null : () => unawaited(_reset()),
                        child: const Text('重設', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 130,
                      height: 60,
                      child: FilledButton(
                        onPressed: _mainAction,
                        child: Text(_mainLabel, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 圓環：底色圓 + 依進度畫的弧
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
