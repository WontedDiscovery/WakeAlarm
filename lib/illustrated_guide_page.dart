import 'package:flutter/material.dart';

import 'core.dart';
import 'liquid_glass.dart';
import 'themes.dart';

/// 畫面圖解：用程式畫出的示意畫面（不是實際截圖）。畫面上的按鈕與文字和實際 App 相同，
/// 圈號對應下方的說明文字。純展示，不讀寫任何資料。
class IllustratedGuidePage extends StatelessWidget {
  const IllustratedGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: const Text('畫面圖解'),
      ),
      body: ThemedBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 24 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Text(
                '下面的畫面是依照程式畫出來的示意圖，外觀會因 iPhone 系統與主題而略有不同。圈號對應下方的說明。',
                style: text.bodySmall,
              ),
            ),
            _GuideCard(
              icon: Icons.home_outlined,
              title: '首頁',
              children: [
                const _Phone(child: _HomeMock()),
                const SizedBox(height: 14),
                const _Legend(items: [
                  '標題的「連續 X 天」是目前的紀錄',
                  '右上角三個按鈕：分享卡片、主題與深色模式、使用教學',
                  '標題下方是下一次響鈴的時間',
                  '鬧鐘卡片：點一下進入編輯',
                  '卡片右邊的開關：暫時關閉或開啟這個鬧鐘',
                  '右下角的「＋」：新增鬧鐘',
                  '底部分頁：鬧鐘、計時器、碼表',
                ]),
              ],
            ),
            _GuideCard(
              icon: Icons.add_alarm,
              title: '新增與編輯鬧鐘',
              children: [
                const _Phone(child: _EditMock()),
                const SizedBox(height: 14),
                _Legend(items: [
                  '時間：點一下開啟時間選擇器',
                  '重複：點星期來選或取消，至少要選一天',
                  '動作：開合跳、舉手、深蹲、閃身步',
                  '次數：按「−」「＋」，每次加減 5 下（5 到 50 下）',
                  '鈴聲：系統預設，或尖叫（自訂）',
                  '右上角的「✓」：儲存',
                  '右上角的垃圾桶：刪除鬧鐘（只有編輯舊鬧鐘時才有）',
                ]),
              ],
            ),
            _GuideCard(
              icon: Icons.directions_run,
              title: '響鈴挑戰畫面',
              children: [
                const _Phone(child: _ChallengeMock()),
                const SizedBox(height: 14),
                _Legend(items: [
                  '上方：目前的動作與次數，達到目標就成功',
                  '剩餘時間：響鈴後 $windowMinutes 分鐘內要做完',
                  '提示文字：告訴你該做哪個動作，或提醒退後一點',
                  '鏡頭畫面：把手機放在能拍到全身的位置',
                ]),
              ],
            ),
            _GuideCard(
              icon: Icons.alarm,
              title: '響鈴時的系統鬧鐘（iOS 26）',
              children: [
                const _AlarmAlertMock(),
                const SizedBox(height: 14),
                const _Legend(items: [
                  '「停止」：只關掉鈴聲；挑戰還沒完成，要再打開 App，在時限內做完',
                  '「開始運動」：打開 App，進入起床挑戰畫面',
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 一張圖解卡片：標題列 + 內容
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveCard(
      color: cardColorOf(context),
      shape: cardShapeOf(context),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 手機外框：固定大小，裡面的畫面不能點（純展示）
class _Phone extends StatelessWidget {
  const _Phone({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 264,
        height: 460,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: scheme.outline, width: 3),
        ),
        child: IgnorePointer(child: child),
      ),
    );
  }
}

// 圖解下方的說明：每一項前面放對應的圈號
class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _Badge(i + 1),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(items[i], style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

// 紅色圈號
class _Badge extends StatelessWidget {
  const _Badge(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
      child: Text(
        '$n',
        style: TextStyle(
          color: scheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

// 在元件左上角貼上圈號
class _Mark extends StatelessWidget {
  const _Mark(this.n, {required this.child});

  final int n;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(top: -8, left: -8, child: _Badge(n)),
      ],
    );
  }
}

// 示意畫面的標題列（和 App 的標題列同色）
class _MockBar extends StatelessWidget {
  const _MockBar({required this.title, this.titleMark, this.actions = const <Widget>[]});

  final String title;
  final int? titleMark;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: scheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w600),
    );
    if (titleMark != null) {
      label = _Mark(titleMark!, child: label);
    }
    return Container(
      height: 56,
      color: scheme.primary,
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Row(
        children: [
          Expanded(child: label),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ],
      ),
    );
  }
}

// 首頁示意：標題與右上角三個按鈕、下一次響鈴、鬧鐘卡片、右下角「＋」、底部分頁
class _HomeMock extends StatelessWidget {
  const _HomeMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MockBar(
          title: '醒動鬧鐘　連續 3 天',
          titleMark: 1,
          actions: [
            _Mark(
              2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _barIcon(Icons.ios_share, fg),
                  const SizedBox(width: 10),
                  _barIcon(Icons.palette, fg),
                  const SizedBox(width: 10),
                  _barIcon(Icons.help_outline, fg),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: _Mark(3, child: Text('下一次響鈴：今天 07:00', style: text.bodySmall)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: _Mark(
            4,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '07:00',
                          style: TextStyle(fontSize: 26, color: scheme.onPrimaryContainer),
                        ),
                        Text('每天｜開合跳 20 下', style: text.bodySmall),
                      ],
                    ),
                  ),
                  _Mark(5, child: Switch(value: true, onChanged: (_) {})),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned(
                right: 14,
                bottom: 12,
                child: _Mark(
                  6,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                    child: Icon(Icons.add, color: scheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: _Mark(
            7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabIcon(context, '鬧鐘', Icons.alarm, selected: true),
                const SizedBox(width: 26),
                _tabIcon(context, '計時器', Icons.timer),
                const SizedBox(width: 26),
                _tabIcon(context, '碼表', Icons.av_timer),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 新增／編輯鬧鐘示意：標題列有垃圾桶與勾勾；下面是時間、重複、動作、次數、鈴聲
class _EditMock extends StatelessWidget {
  const _EditMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = scheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MockBar(
          title: '編輯鬧鐘',
          actions: [
            _Mark(7, child: _barIcon(Icons.delete_outline, fg)),
            _Mark(6, child: _barIcon(Icons.check, fg)),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            children: [
              _MockRow(mark: 1, label: '時間', trailing: Text('07:00', style: text.headlineSmall)),
              const SizedBox(height: 6),
              Text('重複', style: text.bodyLarge),
              const SizedBox(height: 8),
              _Mark(
                2,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      _dayChip(context, '週${dayNames[d - 1]}', selected: d <= 5),
                  ],
                ),
              ),
              const Divider(height: 24),
              _MockRow(mark: 3, label: '動作', trailing: _pick(context, '開合跳')),
              _MockRow(mark: 4, label: '次數', trailing: _stepper(context, '20')),
              _MockRow(mark: 5, label: '鈴聲', trailing: _pick(context, '系統預設')),
            ],
          ),
        ),
      ],
    );
  }
}

// 設定列：左邊是名稱（有圈號），右邊是目前的值或控制項
class _MockRow extends StatelessWidget {
  const _MockRow({required this.mark, required this.label, required this.trailing});

  final int mark;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _Mark(mark, child: Text(label, style: text.bodyLarge)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

// 響鈴挑戰示意：標題、鏡頭畫面、目前的動作與次數、剩餘時間、提示文字
class _ChallengeMock extends StatelessWidget {
  const _ChallengeMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _MockBar(title: '起床挑戰'),
        Expanded(
          child: _Mark(
            4,
            child: SizedBox.expand(
              child: ColoredBox(
                color: const Color(0xFF202026),
                child: Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 96,
                    color: Colors.white.withAlpha(110),
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          color: scheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Mark(
                1,
                child: const Text(
                  '開合跳  3 / 20',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              _Mark(2, child: Text('剩餘 2:41', style: text.bodyMedium)),
              const SizedBox(height: 6),
              _Mark(
                3,
                child: Text(
                  '請對準鏡頭，做出「開合跳」',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 系統鬧鐘提醒示意（iOS 26 的 AlarmKit）：按鈕文字與 App 設定的一樣
class _AlarmAlertMock extends StatelessWidget {
  const _AlarmAlertMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 264,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.alarm_on, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('起床運動', style: text.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Mark(
                      1,
                      child: const _FakeButton(label: '停止', icon: Icons.stop, filled: false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Mark(
                      2,
                      child: const _FakeButton(
                        label: '開始運動',
                        icon: Icons.directions_run,
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '示意圖，實際樣子由 iOS 決定',
                style: text.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 示意用的假按鈕（只是畫出來，不能按）
class _FakeButton extends StatelessWidget {
  const _FakeButton({required this.label, required this.icon, required this.filled});

  final String label;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = filled ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

Widget _barIcon(IconData icon, Color color) => Icon(icon, color: color, size: 22);

// 下拉選單的示意：目前的值 + 箭頭
Widget _pick(BuildContext context, String value) {
  final text = Theme.of(context).textTheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: text.bodyLarge),
      const Icon(Icons.arrow_drop_down),
    ],
  );
}

// 次數的加減按鈕示意：− 數字 ＋
Widget _stepper(BuildContext context, String value) {
  final text = Theme.of(context).textTheme;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.remove),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(value, style: text.bodyLarge),
      ),
      const Icon(Icons.add),
    ],
  );
}

// 星期的小圓角標籤：選到的會有底色
Widget _dayChip(BuildContext context, String label, {required bool selected}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: selected ? scheme.secondaryContainer : null,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outline),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
    ),
  );
}

// 底部分頁的一個圖示
Widget _tabIcon(BuildContext context, String label, IconData icon, {bool selected = false}) {
  final scheme = Theme.of(context).colorScheme;
  final color = selected ? scheme.primary : scheme.onSurfaceVariant;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 20),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ],
  );
}
