import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core.dart';
import 'ringing.dart';

// 目前的主題模式；App 內的深色模式開關會改這裡，MaterialApp 立刻跟著切換
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  final prefs = await SharedPreferences.getInstance();
  final store = Store(prefs);
  appThemeMode.value = _modeOf(store.darkMode);
  runApp(ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => MaterialApp(
      title: '醒動鬧鐘',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: mode,
      home: HomePage(store: store),
    ),
  ));
}

// 從未設定過 = 跟隨系統
ThemeMode _modeOf(bool? dark) =>
    dark == null ? ThemeMode.system : (dark ? ThemeMode.dark : ThemeMode.light);

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

  // 深色模式開關：立刻切換主題，並記住選擇
  Future<void> _setDark(bool dark) async {
    appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    await widget.store.saveDarkMode(dark);
  }

  Future<void> _edit(Alarm? a) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => EditPage(store: widget.store, editing: a),
    ));
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('醒動鬧鐘　連續 $_streak 天'),
        actions: [
          Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 20),
          Switch(value: isDark, onChanged: _setDark),
          const SizedBox(width: 8),
        ],
      ),
      body: _alarms.isEmpty
          ? const Center(child: Text('還沒有鬧鐘，點右下角新增'))
          : ListView(
              children: [
                for (final a in _alarms)
                  ListTile(
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
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
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
        title: Text(editing ? '編輯鬧鐘' : '新增鬧鐘'),
        actions: [
          if (editing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
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
    );
  }
}
