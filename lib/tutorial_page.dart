import 'package:flutter/material.dart';

import 'core.dart';
import 'liquid_glass.dart';
import 'practice_page.dart';
import 'themes.dart';

/// 使用教學頁：說明醒動鬧鐘的操作方式與注意事項（純文字，不讀取任何資料）
class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: const Text('使用教學'),
      ),
      body: ThemedBackdrop(
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 24 + MediaQuery.viewPaddingOf(context).bottom),
          children: [
            _Card(
              icon: Icons.info_outline,
              title: '這是什麼？',
              children: [
                _Bullet('醒動鬧鐘是「運動起床」鬧鐘：時間到會響鈴，你要對著鏡頭做完指定次數的運動，才算成功起床。'),
                _Bullet('響鈴後有 $windowMinutes 分鐘的挑戰時限，時間到還沒做完就記為失敗。'),
              ],
            ),
            _Card(
              icon: Icons.school,
              title: '第一次使用，照這 3 步做',
              children: [
                _Bullet('出現權限提示時請按「允許」：通知會在啟動時詢問，相機在試做時出現，鬧鐘在第一次儲存鬧鐘時出現。'),
                _Bullet('點下面的「試做挑戰」，對著鏡頭做一次動作，確認計數有在跳。'),
                _Bullet('回首頁，點右下角的「＋」新增第一個鬧鐘。'),
                const SizedBox(height: 4),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PracticePage(),
                  )),
                  icon: const Icon(Icons.videocam),
                  label: const Text('試做挑戰'),
                ),
              ],
            ),
            _Card(
              icon: Icons.add_alarm,
              title: '新增與編輯鬧鐘',
              children: [
                _Bullet('點右下角的「＋」新增鬧鐘；點列表裡的鬧鐘可以修改。'),
                _Bullet('設定時間、重複的星期（至少選一天）、運動、次數與鈴聲。次數每次增減 5 下，範圍是 5 到 50 下。'),
                _Bullet('點右上角的勾勾（✓）儲存。'),
                _Bullet('列表右邊的開關可以暫時關閉鬧鐘；編輯頁右上角的垃圾桶可以刪除鬧鐘。'),
              ],
            ),
            _Card(
              icon: Icons.fitness_center,
              title: '四種運動怎麼算？',
              children: [
                for (final e in Exercise.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exerciseName(e), style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(_howTo(e), style: text.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
            _Card(
              icon: Icons.directions_run,
              title: '響鈴時怎麼做？',
              children: [
                _Bullet('鬧鐘響起時，點系統鬧鐘上的「開始運動」（或點通知），就會打開起床挑戰頁，前鏡頭會自動開啟。'),
                _Bullet('對準鏡頭做動作，畫面會即時顯示次數與剩餘時間，次數達標就成功。'),
                _Bullet('挑戰頁不能直接返回，要完成動作，或等時限結束。'),
                _Bullet('按系統鬧鐘的「停止」只會關掉鈴聲，挑戰仍在進行，請在時限內打開 App 完成動作。'),
                _Bullet('不小心關掉挑戰頁？回到首頁，點「鬧鐘挑戰進行中」卡片上的「開始」就能接著做（時限內有效）。'),
              ],
            ),
            _Card(
              icon: Icons.lightbulb_outline,
              title: '讓計數更準',
              children: [
                _Bullet('把手機放在能拍到全身的位置，並退後一點；看不到全身時畫面會提示。'),
                _Bullet('光線要充足，背景盡量單純。'),
                _Bullet('動作幅度要夠大：舉手要超過鼻子、深蹲要蹲到膝蓋明顯彎曲，小幅度的動作可能不會被計入。'),
              ],
            ),
            _Card(
              icon: Icons.local_fire_department,
              title: '成功、失敗與連續天數',
              children: [
                _Bullet('時限內做完指定次數就成功，完成後可以選擇分享今天的成果卡片。'),
                _Bullet('時限到還沒做完就失敗。超過時限才打開 App，會自動補記為失敗。'),
                _Bullet('同一天有多個鬧鐘時，只有最早響的那個會影響連續天數（只看已開啟的鬧鐘）：成功 +1，失敗歸零。'),
                _Bullet('首頁標題的「連續 X 天」就是目前的紀錄，標題下方會顯示下一次響鈴的時間。'),
              ],
            ),
            _Card(
              icon: Icons.palette,
              title: '其他功能',
              children: [
                _Bullet('首頁右上角的「調色盤」可以切換配色、開啟深色模式，或從相簿選一張圖當背景。'),
                _Bullet('首頁右上角的「分享」可以把連續天數做成卡片分享出去。'),
                _Bullet('調色盤頁面裡可以更換 App 圖示（橘、藍、綠、紫、粉紅）。'),
                _Bullet('底部的「計時器」與「碼表」分頁：計時器時間到會發出通知，App 在背景時也會提醒；碼表可以按「圈數」記錄每一圈。'),
              ],
            ),
            _Card(
              icon: Icons.privacy_tip_outlined,
              title: '權限與系統鬧鐘',
              children: [
                _Bullet('iOS 26 以上會使用系統鬧鐘（AlarmKit），準時響鈴，不受靜音與專注模式影響，也會顯示在鎖定畫面。'),
                _Bullet('較舊的 iOS，或系統鬧鐘排不進去時，會改用通知提醒。首頁出現「系統鬧鐘未排入」的紅字，表示該鬧鐘改用通知。'),
                _Bullet('請到 iPhone 的「設定」確認本 App 的通知、鬧鐘與相機權限都已開啟。'),
                _Bullet('相機只用來偵測動作，影像只在手機上處理；選背景圖時才會用到相簿，圖片只存在手機上。'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 每種運動的起點與計數方式（與 ringing.dart 的判斷規則一致）
String _howTo(Exercise e) => switch (e) {
      Exercise.jumpingJack => '從雙手放下、雙腳併攏開始，做到雙手高舉過頭、雙腳打開，再回到起點，算 1 下。',
      Exercise.raiseHands => '從雙手放在肩膀以下開始，舉到手高過鼻子，再放回起點，算 1 下。',
      Exercise.squat => '從站直開始，蹲到膝蓋明顯彎曲，再站回起點，算 1 下。',
      Exercise.flashStep => '左右來回快速閃身，身體每從一邊換到另一邊，算 1 下。',
    };

// 一張說明卡片：標題列 + 內容
class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdaptiveCard(
      color: cardColorOf(context),
      shape: cardShapeOf(context),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 條列的一項：前面是圓點，換行時文字會對齊
class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 18, child: Text('•', style: style)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
