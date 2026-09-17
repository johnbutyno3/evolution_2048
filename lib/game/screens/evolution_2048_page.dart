import '../../services/creature_collection_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/creature.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import '../services/game_engine.dart';
import '../services/audio_manager.dart';
import '../services/haptic_service.dart';
import '../../screens/tools_page.dart';
import '../../services/player_progress_service.dart';
import '../../l10n/app_localizations.dart';

class Evolution2048Page extends StatefulWidget {
  const Evolution2048Page({super.key, this.initialChapter});

  final GameChapter? initialChapter;

  @override
  State<Evolution2048Page> createState() => _Evolution2048PageState();
}

class _Evolution2048PageState extends State<Evolution2048Page>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine _engine;
  final FocusNode _focusNode = FocusNode();
  Offset? _dragStart;
  bool _swipeHandled = false;
  bool _gameOverDialogShowing = false;
  bool _chapterCompleteShowing = false;
  bool _completionAnimationPlaying = false;
  late final AnimationController _completionAnimationController;
  int? _completionAnimationIndex;
  String? _completionAnimationImagePath;
  String? _toolMode;
  int? _firstSwapIndex;
  String? _pressedToolMode;
  int? _evolutionValue;
  String? _evolutionCreatureName;
  Timer? _uiRefreshTimer;
  bool _gameSessionStarting = false;
  static const double _swipeThreshold = 30;

  static const List<String> _oceanBackgrounds = [
    'assets/backgrounds/chapter_01_ocean/ocean_background_01_primordial.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_02_shallow_sea.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_03_coral_reef.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_04_deep_ocean.jpg',
  ];
  static const List<String> _landBackgrounds = [
    'assets/backgrounds/chapter_02_land/land_background_01_primordial.jpg',
    'assets/backgrounds/chapter_02_land/land_background_02_forest.jpg',
    'assets/backgrounds/chapter_02_land/land_background_03_jungle.jpg',
    'assets/backgrounds/chapter_02_land/land_background_04_ancient_land.jpg',
  ];
  static const List<String> _skyBackgrounds = [
    'assets/backgrounds/chapter_03_sky/sky_background_01_low_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_02_mid_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_03_high_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_04_space.jpg',
  ];
  static const List<String> _historyBackgrounds = [
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_01.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_02.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_03.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_04.png',
  ];
  static const List<String> _techBackgrounds = [
    'assets/backgrounds/chapter_05_tech/tech_01_electronic_age.png',
    'assets/backgrounds/chapter_05_tech/tech_02_ai_robot.png',
    'assets/backgrounds/chapter_05_tech/tech_03_future_city.png',
    'assets/backgrounds/chapter_05_tech/tech_04_space_civilization.png',
  ];
  static const List<String> _universeBackgrounds = [
    'assets/backgrounds/chapter_06_universe/universe_bg_01_origin.jpg',
    'assets/backgrounds/chapter_06_universe/universe_bg_02_earth.jpg',
    'assets/backgrounds/chapter_06_universe/universe_bg_03_expansion.jpg',
    'assets/backgrounds/chapter_06_universe/universe_bg_04_civilization.jpg',
  ];

  @override
  void initState() {
    _engine = GameEngine(chapter: widget.initialChapter ?? GameChapter.ocean);
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener(_handleCompletionAnimationStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _resumeGameplay();
      // Do not clear the server-owned active session here. An unfinished
      // session must remain resumable and must not cause another Life spend.
      if (!_engine.gameOver && !_engine.chapterComplete) {
        unawaited(_ensureGameSession());
      }
      unawaited(_engine.refreshToolProgress().then((_) {
        if (mounted) setState(() {});
      }));
      AudioManager.instance.initialize().then((_) {
        if (mounted) AudioManager.instance.playChapterMusic(_engine.chapter);
      });
      if (_engine.gameOver && !_engine.chapterComplete) _showGameOver();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopUiRefreshTimer();
    _engine.pauseGameTimer();
    unawaited(AudioManager.instance.stopMusic());
    _completionAnimationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeGameplay();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _engine.pauseGameTimer();
        _stopUiRefreshTimer();
        break;
    }
  }

  void _resumeGameplay() {
    _engine.updateLifeFromRealTime();
    if (!_engine.gameOver && !_engine.chapterComplete) _engine.startGameTimer();
    _startUiRefreshTimer();
    if (mounted) setState(() {});
  }

  Future<bool> _ensureGameSession() async {
    if (_gameSessionStarting) {
      while (_gameSessionStarting) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final activeChapter = PlayerProgressService.instance.activeGameChapterIndex;
      return PlayerProgressService.instance.activeGameSessionId != null &&
          activeChapter == _chapterNumber - 1;
    }
    _gameSessionStarting = true;
    try {
      final progress = PlayerProgressService.instance;
      await progress.refresh();
      final activeSessionId = progress.activeGameSessionId;
      final activeChapter = progress.activeGameChapterIndex;
      if (activeSessionId != null) {
        if (activeChapter != _chapterNumber - 1) return false;
        return true;
      }
      final started = await progress.restartGameSession(_chapterNumber - 1);
      if (!started) return false;
      _engine.markBoardLifeActiveAfterServerRestart();
      if (mounted) setState(() {});
      return true;
    } finally {
      _gameSessionStarting = false;
    }
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _engine.updateLifeFromRealTime();
      if (mounted) setState(() {});
    });
  }

  void _stopUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
  }

  void _handleCompletionAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _showChapterComplete();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_gameOverDialogShowing || _chapterCompleteShowing ||
        _completionAnimationPlaying || _toolMode != null) {
      return KeyEventResult.handled;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 'up',
      LogicalKeyboardKey.arrowDown => 'down',
      LogicalKeyboardKey.arrowLeft => 'left',
      LogicalKeyboardKey.arrowRight => 'right',
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    _move(direction);
    return KeyEventResult.handled;
  }

  void _handleDragStart(DragStartDetails details) {
    if (_gameOverDialogShowing || _chapterCompleteShowing ||
        _completionAnimationPlaying || _toolMode != null) return;
    _dragStart = details.localPosition;
    _swipeHandled = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_gameOverDialogShowing || _chapterCompleteShowing || _toolMode != null ||
        _swipeHandled || _dragStart == null) return;
    final delta = details.localPosition - _dragStart!;
    if (delta.distance < _swipeThreshold) return;
    final direction = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx < 0 ? 'left' : 'right')
        : (delta.dy < 0 ? 'up' : 'down');
    _swipeHandled = true;
    _move(direction);
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragStart = null;
    _swipeHandled = false;
  }

  void _move(String direction) {
    if (_gameOverDialogShowing || _chapterCompleteShowing ||
        _completionAnimationPlaying || _toolMode != null) return;
    bool changed;
    switch (direction) {
      case 'up': changed = _engine.moveUp(); break;
      case 'down': changed = _engine.moveDown(); break;
      case 'left': changed = _engine.moveLeft(); break;
      case 'right': changed = _engine.moveRight(); break;
      default: return;
    }
    if (!changed) return;
    unawaited(AudioManager.instance.playSfx(GameSfx.tileMove));
    unawaited(_handleMoveResult());
    if (mounted) setState(() {});
  }

  Future<void> _handleMoveResult() async {
    final evolution = _engine.consumeLatestEvolution();
    if (evolution != null) {
      _evolutionValue = evolution.value;
      _evolutionCreatureName = evolution.creature.name;
      unawaited(CreatureCollectionService.discover(
        chapter: _engine.chapter,
        value: evolution.value,
      ));
    }
    if (_engine.chapterComplete && !_completionAnimationPlaying) {
      _completionAnimationPlaying = true;
      _completionAnimationController.forward(from: 0);
    } else if (_engine.gameOver && !_gameOverDialogShowing) {
      _showGameOver();
    }
    if (mounted) setState(() {});
  }

  void _showResetMenu() {
    showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('回首頁'),
              onTap: () => Navigator.pop(context, 'home'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('重玩'),
              onTap: () => Navigator.pop(context, 'restart'),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('繼續'),
              onTap: () => Navigator.pop(context, 'continue'),
            ),
          ],
        ),
      ),
    ).then((choice) {
      if (!mounted || choice == null || choice == 'continue') return;
      if (choice == 'home') {
        _engine.pauseGameTimer();
        Navigator.of(context).pop();
      } else if (choice == 'restart') {
        unawaited(_restartGame());
      }
    });
  }

  Future<void> _restartGame() async {
    if (_gameSessionStarting) return;
    _gameSessionStarting = true;
    try {
      final started = await PlayerProgressService.instance.restartGameSession(
        _chapterNumber - 1,
      );
      if (!started) return;
      _engine.reset();
      _engine.markBoardLifeActiveAfterServerRestart();
      _toolMode = null;
      _firstSwapIndex = null;
      _pressedToolMode = null;
      _evolutionValue = null;
      _evolutionCreatureName = null;
      _completionAnimationPlaying = false;
      _resumeGameplay();
      if (mounted) setState(() {});
    } finally {
      _gameSessionStarting = false;
    }
  }

  Future<void> _showToolUnavailable(String toolName) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ondemand_video_outlined),
              title: Text('取得 $toolName'),
              subtitle: const Text('可觀看 Rewarded Ad 取得額外使用次數'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('前往商城'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ToolsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // The remainder of the existing rendering, tool handling, completion and
  // game-over methods remains unchanged below this point.
