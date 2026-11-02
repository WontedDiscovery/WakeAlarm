import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core.dart';
import 'ringing.dart';
import 'themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  final prefs = await SharedPreferences.getInstance();
  final store = Store(prefs);
  loadTheme(store); // 讀取上次選的主題與深色模式
  runApp(ValueListenableBuilder<ThemeChoice>(
    valueListenable: appThemeChoice,
    builder: (context, choice, _) => MaterialApp(
      title: '醒動鬧鐘',
      theme: buildTheme(choice.preset, Brightness.light),
      darkTheme: buildTheme(choice.preset, Brightness.dark),
      themeMode: choice.mode,
      home: HomePage(store: store),
    ),
  ));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final Store store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Alarm> _alarms = [];
  int _streak = 0;
  bool _ringOpen = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _checkRing());
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  // 補記過期響鈴 → 重新排程 → 更新畫面 → 檢查是否正在響鈴
  Future<void> _refresh() async {
    final now = DateTime.now();
    await settleMissed(widget.store, now);
    await rescheduleAll(widget.store, widget.store.alarms, now);
    if (!mounted) return;
    setState(() {
      _alarms = widget.store.alarms;
      _streak = widget.store.streak;
    });
    _checkRing();
  }

  Future<void> _checkRing() async {
    if (_ringOpen || !mounted) return;
    final ring = findRinging(widget.store, DateTime.now());
    if (ring == null) return;
    _ringOpen = true;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RingingPage(store: widget.store, ring: ring),
    ));
    _ringOpen = false;
    _refresh();
  }

  Future<void> _save() async {
    await widget.store.saveAlarms(_alarms);
    await rescheduleAll(widget.store, _alarms, DateTime.now());
    if (mounted) setState(() {});
  }

  Future<void> _edit(Alarm? a) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => EditPage(store: widget.store, editing: a),
    ));
    if (changed == true) _refresh();
  }

  Future<void> _openThemes() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ThemePage(store: widget.store),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decor = decorOf(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: Text('醒動鬧鐘　連續 $_streak 天'),
        actions: [
          IconButton(
            tooltip: '主題與深色模式',
            icon: const Icon(Icons.palette),
            onPressed: _openThemes,
          ),
        ],
      ),
      body: ThemedBackdrop(
        child: _alarms.isEmpty
            ? const Center(child: Text('還沒有鬧鐘，點右下角新增'))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final a in _alarms)
                    Card(
                      color: cardColorOf(context),
                      shape: cardShapeOf(context),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(hhmm(a.hour, a.minute), style: const TextStyle(fontSize: 28)),
                        subtitle: Text('${daysText(a.days)}｜${exerciseName(a.exercise)} ${a.target} 下'),
                        onTap: () => _edit(a),
                        trailing: Switch(
                          value: a.enabled,
                          onChanged: (v) {
                            a.enabled = v;
                            _save();
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: decor.accent,
        foregroundColor: decor.onAccent,
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// 主題頁：深色模式開關 ＋ 所有主題（點一下立刻套用）
class ThemePage extends StatelessWidget {
  const ThemePage({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: const Text('主題與深色模式'),
      ),
      body: ThemedBackdrop(
        child: ValueListenableBuilder<ThemeChoice>(
          valueListenable: appThemeChoice,
          builder: (context, choice, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                title: const Text('深色模式'),
                secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                value: isDark,
                onChanged: (v) => setDarkMode(store, v),
              ),
              const Divider(),
              for (final p in kThemePresets)
                ListTile(
                  leading: p.art == null
                      ? _Swatch(p)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(p.art!, width: 56, height: 40, fit: BoxFit.cover),
                        ),
                  title: Text(p.name),
                  trailing: p.id == choice.preset.id ? const Icon(Icons.check_circle) : null,
                  onTap: () => setThemePreset(store, p),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 主題預覽：主色、次要色、第三色三個圓點
class _Swatch extends StatelessWidget {
  const _Swatch(this.preset);
  final AppThemePreset preset;

  @override
  Widget build(BuildContext context) {
    final s = schemeFor(preset, Brightness.light);
    Widget dot(Color c) => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return SizedBox(
      width: 56,
      child: Row(
        children: [
          dot(s.primary),
          const SizedBox(width: 4),
          dot(s.secondary),
          const SizedBox(width: 4),
          dot(s.tertiary),
        ],
      ),
    );
  }
}

class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.store, this.editing});
  final Store store;
  final Alarm? editing;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late int _hour = widget.editing?.hour ?? 7;
  late int _minute = widget.editing?.minute ?? 0;
  late Set<int> _days =
      widget.editing == null ? {1, 2, 3, 4, 5, 6, 7} : {...widget.editing!.days};
  late Exercise _exercise = widget.editing?.exercise ?? Exercise.jumpingJack;
  late int _target = widget.editing?.target ?? 20;

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (t != null) {
      setState(() {
        _hour = t.hour;
        _minute = t.minute;
      });
    }
  }

  Future<void> _save() async {
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請至少選一天')));
      return;
    }
    final old = widget.editing;
    final all = widget.store.alarms;
    final alarm = Alarm(
      id: old?.id ?? _newId(all),
      hour: _hour,
      minute: _minute,
      days: _days,
      exercise: _exercise,
      target: _target,
      enabled: old?.enabled ?? true,
      createdAt: old?.createdAt ?? DateTime.now(),
    );
    await _write([...all.where((a) => a.id != alarm.id), alarm]);
  }

  Future<void> _delete() =>
      _write(widget.store.alarms.where((a) => a.id != widget.editing!.id).toList());

  Future<void> _write(List<Alarm> list) async {
    await widget.store.saveAlarms(list);
    await rescheduleAll(widget.store, list, DateTime.now());
    if (mounted) Navigator.of(context).pop(true);
  }

  int _newId(List<Alarm> all) {
    var id = DateTime.now().millisecondsSinceEpoch % 100000;
    while (all.any((a) => a.id == id)) {
      id = (id + 1) % 100000;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: Text(editing ? '編輯鬧鐘' : '新增鬧鐘'),
        actions: [
          if (editing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ThemedBackdrop(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('時間'),
            trailing: Text(hhmm(_hour, _minute), style: const TextStyle(fontSize: 24)),
            onTap: _pickTime,
          ),
          const Text('重複'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text('週${dayNames[d - 1]}'),
                  selected: _days.contains(d),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _days.add(d);
                    } else {
                      _days.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const Divider(height: 32),
          ListTile(
            title: const Text('動作'),
            trailing: DropdownButton<Exercise>(
              value: _exercise,
              items: [
                for (final e in Exercise.values)
                  DropdownMenuItem(value: e, child: Text(exerciseName(e))),
              ],
              onChanged: (v) => setState(() => _exercise = v ?? _exercise),
            ),
          ),
          ListTile(
            title: const Text('次數'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _target > 5 ? () => setState(() => _target -= 5) : null,
                ),
                Text('$_target'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _target < 50 ? () => setState(() => _target += 5) : null,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
