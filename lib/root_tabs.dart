import 'package:flutter/material.dart';

import 'core.dart';
import 'liquid_glass.dart';
import 'stopwatch_page.dart';
import 'themes.dart';
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
    final pages = IndexedStack(
      index: _index,
      children: [
        widget.alarmPage,
        TimerPage(store: widget.store),
        const StopwatchPage(),
      ],
    );

    if (kLiquidGlass) {
      // iOS 26：系統導覽列（UITabBar，液態玻璃）懸在內容上面；
      // 內容延伸到它後面，玻璃才會折射出背後的畫面
      final tint = decorOf(context).accent ?? Theme.of(context).colorScheme.primary;
      final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
      return Scaffold(
        extendBody: true,
        body: pages,
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + safeBottom),
          child: SizedBox(
            height: kNativeTabBarHeight,
            child: NativeTabBar(
              index: _index,
              tint: tint,
              dark: Theme.of(context).brightness == Brightness.dark,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: pages,
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
