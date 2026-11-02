import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'core.dart';

PoseLandmark? _lm(Pose p, PoseLandmarkType t) {
  final l = p.landmarks[t];
  return (l != null && l.likelihood >= 0.5) ? l : null;
}

double? _kneeAngle(Pose p, bool left) {
  final h = _lm(p, left ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip);
  final k = _lm(p, left ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee);
  final a = _lm(p, left ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle);
  if (h == null || k == null || a == null) return null;
  final ux = h.x - k.x, uy = h.y - k.y, vx = a.x - k.x, vy = a.y - k.y;
  final m = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy);
  if (m == 0) return null;
  return acos(((ux * vx + uy * vy) / m).clamp(-1.0, 1.0)) * 180 / pi;
}

// 1 = 起始姿勢，2 = 目標姿勢，null = 中間或看不清楚（規格第十二章）
int? _classify(Pose p, Exercise e) {
  if (e == Exercise.squat) {
    final angles = [for (final left in [true, false]) _kneeAngle(p, left)].whereType<double>().toList();
    if (angles.isEmpty) return null;
    final knee = angles.reduce((x, y) => x + y) / angles.length;
    return knee > 160 ? 1 : (knee < 100 ? 2 : null);
  }
  final ls = _lm(p, PoseLandmarkType.leftShoulder);
  final rs = _lm(p, PoseLandmarkType.rightShoulder);
  final lw = _lm(p, PoseLandmarkType.leftWrist);
  final rw = _lm(p, PoseLandmarkType.rightWrist);
  final nose = _lm(p, PoseLandmarkType.nose);
  if (ls == null || rs == null || lw == null || rw == null || nose == null) return null;
  final down = lw.y > ls.y && rw.y > rs.y; // y 軸向下：手腕低於肩
  final up = lw.y < nose.y && rw.y < nose.y; // 手腕高於鼻
  if (e == Exercise.raiseHands) return down ? 1 : (up ? 2 : null);
  final la = _lm(p, PoseLandmarkType.leftAnkle);
  final ra = _lm(p, PoseLandmarkType.rightAnkle);
  final sw = (ls.x - rs.x).abs();
  if (la == null || ra == null || sw < 1) return null;
  final legs = (la.x - ra.x).abs();
  if (down && legs < 1.1 * sw) return 1;
  if (up && legs > 1.5 * sw) return 2;
  return null;
}

class RepCounter {
  int count = 0;
  int? _stable;
  int? _cand;
  int _frames = 0;
  bool _armed = false;
  bool _reached = false;

  // 連續 3 幀維持同一姿勢才算數；起始 → 目標 → 起始 計 1 下
  void update(Pose p, Exercise e) {
    final c = _classify(p, e);
    if (c == null) {
      _cand = null;
      _frames = 0;
      return;
    }
    _frames = c == _cand ? _frames + 1 : 1;
    _cand = c;
    if (_frames < 3 || c == _stable) return;
    _stable = c;
    if (c == 2 && _armed) _reached = true;
    if (c == 1) {
      _armed = true;
      if (_reached) {
        count++;
        _reached = false;
      }
    }
  }
}

// 在背景釋放相機（不阻塞畫面）
Future<void> _disposeCamera(CameraController c) async {
  try {
    if (c.value.isStreamingImages) await c.stopImageStream();
  } catch (_) {}
  try {
    await c.dispose();
  } catch (_) {}
}

class RingingPage extends StatefulWidget {
  const RingingPage({super.key, required this.store, required this.ring});
  final Store store;
  final Ring ring;

  @override
  State<RingingPage> createState() => _RingingPageState();
}

class _RingingPageState extends State<RingingPage> with WidgetsBindingObserver {
  final _detector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  final _counter = RepCounter();
  late final DateTime _deadline =
      widget.ring.alarm.ringAt(widget.ring.day).add(const Duration(minutes: windowMinutes));
  late int _left = _deadline.difference(DateTime.now()).inSeconds;
  CameraController? _cam;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  String _hint = '準備鏡頭中…';
  bool _busy = false;
  bool _done = false;
  bool _active = true; // App 在前景才能用相機
  bool _starting = false; // 正在啟動相機，避免重複啟動
  Timer? _timer;
  Timer? _retry; // 相機沒開成功時，每 2 秒重試一次

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _retry = Timer.periodic(const Duration(seconds: 2), (_) => _ensureCamera());
    _ensureCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _retry?.cancel();
    _releaseCamera(showHint: false);
    _detector.close();
    super.dispose();
  }

  // 切到背景，或被系統畫面（例如鬧鐘）蓋住時，系統會停掉相機：先關掉，回到前景再重新開
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _active) return;
    _active = active;
    if (active) {
      _ensureCamera();
    } else {
      _releaseCamera(showHint: true);
    }
  }

  void _tick() {
    if (_done) return;
    final left = _deadline.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _finish(false);
    } else if (mounted) {
      setState(() => _left = left);
    }
  }

  // 需要相機、但還沒開，而且 App 在前景、沒有正在啟動時，才啟動
  void _ensureCamera() {
    if (_done || !_active || _starting || _cam != null) return;
    _startCamera();
  }

  void _releaseCamera({required bool showHint}) {
    final c = _cam;
    _cam = null;
    if (showHint && mounted) {
      setState(() => _hint = '請回到 App 畫面，鏡頭會自動開啟');
    }
    if (c != null) unawaited(_disposeCamera(c));
  }

  Future<void> _startCamera() async {
    _starting = true;
    CameraController? c;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw StateError('找不到鏡頭');
      final cam = cams.firstWhere(
        (x) => x.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      c = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      // 初始化期間 App 可能已切到背景，或這一頁已經結束
      if (!mounted || _done || !_active) {
        unawaited(_disposeCamera(c));
        return;
      }
      _rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      _cam = c;
      await c.startImageStream(_onImage);
      if (mounted) {
        setState(() => _hint = '請對準鏡頭，做出「${exerciseName(widget.ring.alarm.exercise)}」');
      }
    } catch (e) {
      final failed = c;
      if (failed != null) {
        if (identical(_cam, failed)) _cam = null;
        unawaited(_disposeCamera(failed));
      }
      if (mounted) setState(() => _hint = _errorText(e));
    } finally {
      _starting = false;
    }
  }

  String _errorText(Object e) {
    if (e is CameraException && e.code.startsWith('CameraAccess')) {
      return '沒有相機權限，請到「設定」開啟本 App 的相機權限';
    }
    return _active ? '鏡頭暫時無法使用，會自動重試' : '請回到 App 畫面，鏡頭會自動開啟';
  }

  Future<void> _onImage(CameraImage img) async {
    if (_busy || _done || _cam == null) return;
    _busy = true;
    try {
      final plane = img.planes.first;
      final input = InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(img.width.toDouble(), img.height.toDouble()),
          rotation: _rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final poses = await _detector.processImage(input);
      if (!mounted || _done) return;
      if (poses.isEmpty) {
        setState(() => _hint = '看不到全身，請退後一點');
        return;
      }
      _counter.update(poses.first, widget.ring.alarm.exercise);
      if (_counter.count >= widget.ring.alarm.target) {
        _finish(true);
      } else {
        setState(() {});
      }
    } catch (_) {
      // 單一影格失敗就略過，下一幀再試
    } finally {
      _busy = false;
    }
  }

  Future<void> _finish(bool ok) async {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    _retry?.cancel();
    _releaseCamera(showHint: false);
    try {
      await resolve(widget.store, widget.ring.alarm, widget.ring.day, ok);
    } catch (e) {
      debugPrint('寫入結果時出錯：$e');
    }
    await silenceAlarm(widget.ring.alarm); // 挑戰結束就關掉系統鬧鐘的響鈴
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '完成！本次記為成功' : '時限已到，本次記為失敗')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = widget.ring.alarm;
    final cam = _cam;
    final ready = cam != null && cam.value.isInitialized;
    final ss = (_left % 60).toString().padLeft(2, '0');
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('起床挑戰'), automaticallyImplyLeading: false),
        body: Column(
          children: [
            Expanded(
              child: cam != null && cam.value.isInitialized
                  ? CameraPreview(cam)
                  : const Center(child: CircularProgressIndicator()),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${exerciseName(alarm.exercise)}  ${_counter.count} / ${alarm.target}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  Text('剩餘 ${_left ~/ 60}:$ss'),
                  const SizedBox(height: 8),
                  Text(_hint, textAlign: TextAlign.center),
                  if (!ready && !_done) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _ensureCamera,
                      child: const Text('重新啟動鏡頭'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
