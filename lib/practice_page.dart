import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'core.dart';
import 'liquid_glass.dart';
import 'ringing.dart';
import 'themes.dart';

/// 試做挑戰：用前鏡頭實際練習動作計數。計數用的是響鈴時同一套 RepCounter，
/// 但不寫入任何紀錄、不影響連續天數，也不會關掉任何鬧鐘。
class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> with WidgetsBindingObserver {
  final _detector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  RepCounter _counter = RepCounter();
  Exercise _exercise = Exercise.jumpingJack;
  int _target = 10;
  CameraController? _cam;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  String _hint = '準備鏡頭中…';
  bool _busy = false; // 上一張影格還在處理中，就略過這一張
  bool _done = false; // 已達目標：停止計數
  bool _active = true; // App 在前景才能用相機
  bool _starting = false; // 正在啟動相機，避免重複啟動

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    _ensureCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseCamera();
    _detector.close();
    super.dispose();
  }

  // 切到背景時先關掉相機，回到前景再重新開
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _active) return;
    _active = active;
    if (active) {
      _ensureCamera();
    } else {
      _releaseCamera();
      if (mounted) setState(() => _hint = '請回到 App 畫面，鏡頭會自動開啟');
    }
  }

  // 還沒開相機、App 在前景、也沒有正在啟動時，才啟動
  void _ensureCamera() {
    if (!_active || _starting || _cam != null) return;
    unawaited(_startCamera());
  }

  void _releaseCamera() {
    final c = _cam;
    _cam = null;
    if (c != null) unawaited(_disposePracticeCamera(c));
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
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await c.initialize();
      // 初始化期間 App 可能已切到背景，或這一頁已經關掉
      if (!mounted || !_active) {
        unawaited(_disposePracticeCamera(c));
        return;
      }
      _rotation = InputImageRotationValue.fromRawValue(cam.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      _cam = c;
      await c.startImageStream(_onImage);
      if (mounted) setState(() => _hint = _promptText());
    } catch (e) {
      final failed = c;
      if (failed != null) {
        if (identical(_cam, failed)) _cam = null;
        unawaited(_disposePracticeCamera(failed));
      }
      if (mounted) setState(() => _hint = _errorText(e));
    } finally {
      _starting = false;
    }
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
          format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
      final poses = await _detector.processImage(input);
      if (!mounted || _done) return;
      if (poses.isEmpty) {
        setState(() => _hint = '看不到全身，請退後一點');
        return;
      }
      _counter.update(poses.first, _exercise);
      setState(() {
        if (_counter.count >= _target) {
          _done = true;
        } else {
          _hint = _promptText();
        }
      });
    } catch (_) {
      // 單一影格失敗就略過，下一幀再試
    } finally {
      _busy = false;
    }
  }

  String _promptText() => '請對準鏡頭，做出「${exerciseName(_exercise)}」${exerciseTip(_exercise)}';

  String _errorText(Object e) {
    if (e is CameraException && e.code.startsWith('CameraAccess')) {
      return '沒有相機權限，請到「設定」開啟本 App 的相機權限';
    }
    return _active ? '鏡頭暫時無法使用，可以按下方按鈕重新啟動' : '請回到 App 畫面，鏡頭會自動開啟';
  }

  void _changeExercise(Exercise? e) {
    if (e == null || e == _exercise) return;
    setState(() {
      _exercise = e;
      _counter = RepCounter();
      _done = false;
      _hint = _promptText();
    });
  }

  void _changeTarget(int t) {
    setState(() {
      _target = t;
      _counter = RepCounter();
      _done = false;
    });
  }

  void _reset() {
    setState(() {
      _counter = RepCounter();
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cam = _cam;
    final ready = cam != null && cam.value.isInitialized;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        flexibleSpace: appBarHeader(context),
        title: const Text('試做挑戰'),
      ),
      body: ThemedBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: AdaptiveCard(
                color: cardColorOf(context),
                shape: cardShapeOf(context),
                margin: EdgeInsets.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('動作'),
                      trailing: DropdownButton<Exercise>(
                        value: _exercise,
                        items: [
                          for (final e in Exercise.values)
                            DropdownMenuItem(value: e, child: Text(exerciseName(e))),
                        ],
                        onChanged: _changeExercise,
                      ),
                    ),
                    ListTile(
                      title: const Text('次數'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _target > 5 ? () => _changeTarget(_target - 5) : null,
                          ),
                          Text('$_target'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _target < 50 ? () => _changeTarget(_target + 5) : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '這裡只是練習，不會計入連續天數，也不會影響任何鬧鐘。',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: cam != null && cam.value.isInitialized
                    ? CameraPreview(cam)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${exerciseName(_exercise)}  ${_counter.count} / $_target',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _done ? '做到了！真的鬧鐘響的時候，做到這個次數就算成功。' : _hint,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
              child: ready
                  ? FilledButton.tonal(onPressed: _reset, child: Text(_done ? '再練一次' : '重新計數'))
                  : FilledButton.tonal(onPressed: _ensureCamera, child: const Text('重新啟動鏡頭')),
            ),
          ],
        ),
      ),
    );
  }
}

// 關閉相機的收尾（與 ringing.dart 的做法相同，這裡是獨立的一份）
Future<void> _disposePracticeCamera(CameraController c) async {
  try {
    if (c.value.isStreamingImages) await c.stopImageStream();
  } catch (_) {}
  try {
    await c.dispose();
  } catch (_) {}
}
