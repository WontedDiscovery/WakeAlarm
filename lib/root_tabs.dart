import 'package:flutter/material.dart';

import 'core.dart';
import 'stopwatch_page.dart';
import 'timer_page.dart';

/// 最外層的分頁：鬧鐘 / 計時器 / 碼表（用 IndexedStack，切換分頁時狀態不會消失）
class RootTabs extends StatefulWidget {
  const RootTabs({super.key, required this.store, required this.alarmPage});

  final Store store;
  final Widget alarmPage;

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          widget.alarmPage,
          TimerPage(store: widget.store),
          const StopwatchPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.alarm), label: '鬧鐘'),
          NavigationDestination(icon: Icon(Icons.timer), label: '計時器'),
          NavigationDestination(icon: Icon(Icons.av_timer), label: '碼表'),
        ],
      ),
    );
  }
}
