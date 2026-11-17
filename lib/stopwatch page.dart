import 'dart:async';

import 'package:flutter/material.dart';

import 'themes.dart';

/// 碼表格式：分:秒.百分之一秒（超過一小時會顯示時）
String fmtStopwatch(Duration d) {
  final cs = (d.inMilliseconds % 1000) ~/ 10;
  final totalSec = d.inSeconds;
  final s = totalSec % 60;
  final m = (totalSec ~/ 60) % 60;
  final h = totalSec ~/ 3600;
  String two(int v) => v.toString().padLeft(2, '0');
  final core = h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  return '$core.${two(cs)}';
}

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;
  final List<Duration> _laps = []; // 每一圈結束時的總時間，最新的在最前面

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_sw.isRunning) {
      _sw.stop();
      _ticker?.cancel();
    } else {
      _sw.start();
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => setState(() {}));
    }
    setState(() {});
  }

  void _lap() => setState(() => _laps.insert(0, _sw.elapsed));

  void _reset() {
    _sw.reset();
    _ticker?.cancel();
    setState(() => _laps.clear());
  }

  @override
  Widget build(BuildContext context) {
    final running = _sw.isRunning;
    final elapsed = _sw.elapsed;
    final canReset = !running && elapsed > Duration.zero;
    // 每一圈的單圈時間 = 這圈的總時間 - 上一圈的總時間
    final splits = [
      for (var i = 0; i < _laps.length; i++)
        _laps[i] - (i + 1 < _laps.length ? _laps[i + 1] : Duration.zero),
    ];

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: appBarHeader(context),
        title: const Text('碼表'),
      ),
      body: ThemedBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text(
                fmtStopwatch(elapsed),
                style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 60,
                    child: OutlinedButton(
                      onPressed: running ? _lap : (canReset ? _reset : null),
                      child: Text(running ? '圈數' : '重設', style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 130,
                    height: 60,
                    child: FilledButton(
                      onPressed: _toggle,
                      child: Text(running ? '停止' : '開始', style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Expanded(
                child: _laps.isEmpty
                    ? const Center(child: Text('還沒有圈數紀錄'))
                    : ListView.builder(
                        itemCount: _laps.length,
                        itemBuilder: (context, i) => ListTile(
                          title: Text('第 ${_laps.length - i} 圈'),
                          subtitle: Text('單圈 ${fmtStopwatch(splits[i])}'),
                          trailing: Text(fmtStopwatch(_laps[i])),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
