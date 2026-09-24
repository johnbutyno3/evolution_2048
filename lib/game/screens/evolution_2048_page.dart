import '../../services/creature_collection_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/creature.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import '../services/game_engine.dart';
import '../services/save_manager.dart';
import '../services/audio_manager.dart';
import '../services/haptic_service.dart';
import '../../screens/tools_page.dart';
import '../../services/player_progress_service.dart';
import '../services/life_manager.dart';
import '../services/tool_manager.dart';
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
  Future<bool>? _gameSessionFuture;
  int _gameSessionGeneration = 0;
  bool _restartInProgress = false;
  bool _allowSystemPop = false;
  bool _handlingSystemBack = false;

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
    super.initState();
    _engine = GameEngine(chapter: widget.initialChapter ?? GameChapter.ocean);
    WidgetsBinding.instance.addObserver(this);
    _completionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addStatusListener(_handleCompletionAnimationStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeGameplaySession());
      AudioManager.instance.initialize().then((_) {
        if (mounted) AudioManager.instance.playChapterMusic(_engine.chapter);
      });
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
    if (!_engine.gameOver && !_engine.chapterComplete) _engine.startGameTimer();
    _startUiRefreshTimer();
    if (mounted) setState(() {});
  }

  Future<void> _initializeGameplaySession() async {
    if (!mounted) return;

    final ready = await _ensureGameSession();
    if (!mounted) return;

    if (!ready) {
      if (_engine.gameOver && !_engine.chapterComplete) {
        await _showGameOver();
      }
      return;
    }

    _resumeGameplay();
    _focusNode.requestFocus();

    if (_engine.gameOver && !_engine.chapterComplete) {
      await _showGameOver();
    }
  }

  Future<bool> _ensureGameSession() {
    final existing = _gameSessionFuture;
    if (existing != null) return existing;

    final future = _createGameSession();
    _gameSessionFuture = future;
    future.whenComplete(() {
      if (identical(_gameSessionFuture, future)) {
        _gameSessionFuture = null;
      }
    });
    return future;
  }

  Future<bool> _createGameSession() async {
    final generation = _gameSessionGeneration;
    try {
      final progress = PlayerProgressService.instance;
      // Home already loads authoritative progress. Only fetch here when this
      // page was entered without a current server snapshot.
      if (!progress.loadedFromServer) await progress.refresh();
      if (!mounted || generation != _gameSessionGeneration) return false;
      final activeSessionId = progress.activeGameSessionId;
      final activeChapter = progress.activeGameChapterIndex;

      if (activeSessionId != null) {
        if (activeChapter != _chapterNumber - 1) return false;

        // Session ownership is resolved in PlayerProgressService.
        // It compares the server session with the local save binding:
        // matching session -> resume without another Life;
        // missing/mismatched board -> replace the orphaned session and charge
        // exactly one Life for the new game.
        final entered =
            await progress.resumeGameSession(_chapterNumber - 1);
        if (!entered || !mounted || generation != _gameSessionGeneration) return false;

        // The service has already decided whether this was a resume or a
        // fresh replacement. This local check is only for choosing whether
        // to restore the matching cached board into the new engine.
        final saved = SaveManager.loadCached(
          chapter: _engine.chapter.name,
        );
        final hasPlayableLocalBoard = saved != null &&
            saved['gameSessionId'] == progress.activeGameSessionId &&
            saved['gameOver'] != true &&
            saved['chapterComplete'] != true &&
            saved['tiles'] is List &&
            (saved['tiles'] as List).length == 16;

        // Load the server-authoritative tool inventory before constructing the
        // engine so the board's ToolManager reflects the current account.
        await ToolManager.refreshInventory();
        if (!mounted || generation != _gameSessionGeneration) return false;

        if (hasPlayableLocalBoard) {
          // Resuming an unfinished server session means this restored board
          // already owns the Life that was charged when the session began.
          // Recreate the engine with explicit Life ownership so Game Over
          // handling and timer shutdown remain correct after resume.
          final chapter = _engine.chapter;
          _engine.stopGameTimer();
          _engine = GameEngine(
            chapter: chapter,
            boardLifeActive: true,
          );
        } else {
          // The new server session owns a new board; do not restore the
          // orphaned cached session into this engine.
          _engine.stopGameTimer();
          _engine = GameEngine(
            chapter: _engine.chapter,
            forceNewBoard: true,
            boardLifeActive: true,
          );
        }

        return true;
      }

      if (_engine.gameOver || _engine.chapterComplete) {
        return false;
      }

      final started = await progress.startGameSession(_chapterNumber - 1);
      if (!started || !mounted || generation != _gameSessionGeneration) return false;

      // Load the server-authoritative tool inventory before constructing the
      // new engine so tool buttons are immediately usable.
      await ToolManager.refreshInventory();
      if (!mounted || generation != _gameSessionGeneration) return false;

      // The server has just consumed the Life for this explicit game entry.
      // If this entry follows a normal unfinished exit, the cached board is
      // rebound to the new session and should continue from where the player
      // left. A genuinely new game has no playable cached board.
      final saved = SaveManager.loadCached(
        chapter: _engine.chapter.name,
      );
      final hasPlayableLocalBoard = saved != null &&
          saved['gameSessionId'] == progress.activeGameSessionId &&
          saved['gameOver'] != true &&
          saved['chapterComplete'] != true &&
          saved['tiles'] is List &&
          (saved['tiles'] as List).length == 16;
      _engine.stopGameTimer();
      _engine = GameEngine(
        chapter: _engine.chapter,
        forceNewBoard: !hasPlayableLocalBoard,
        boardLifeActive: true,
      );
      // Tool inventory is authoritative but must not delay creation of the
      // new board. Refresh it in the background after the session is active.
      return true;
    } catch (error) {
      debugPrint('Failed to create game session: $error');
      return false;
    }
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      LifeManager.tickRegeneration();
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
        _completionAnimationPlaying || _toolMode != null) {
      return;
    }
    _dragStart = details.localPosition;
    _swipeHandled = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_gameOverDialogShowing || _chapterCompleteShowing || _toolMode != null ||
        _swipeHandled || _dragStart == null) {
      return;
    }
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
        _completionAnimationPlaying || _toolMode != null) {
      return;
    }
    bool changed;
    switch (direction) {
      case 'up': changed = _engine.moveUp(); break;
      case 'down': changed = _engine.moveDown(); break;
      case 'left': changed = _engine.moveLeft(); break;
      case 'right': changed = _engine.moveRight(); break;
      default: changed = false;
    }
    if (!changed) return;
    final newEvolutionValues = _engine.newEvolutionValuesThisMove;
    final mergedValues = _engine.board.lastMergedValues;
    if (mergedValues.isNotEmpty) {
      unawaited(CreatureCollectionService.discover(
        _engine.chapter.name,
        mergedValues,
      ));
    }
    if (newEvolutionValues.isNotEmpty) {
      AudioManager.instance.playSfx(GameSfx.tileMerge);
    } else {
      AudioManager.instance.playSfx(GameSfx.tileMove);
    }
    if (mounted) setState(() {});
    if (newEvolutionValues.isNotEmpty) {
      _showEvolutionNotice(newEvolutionValues.last);
      HapticService.evolutionImpact();
    }
    if (_engine.chapterComplete) {
      if (newEvolutionValues.contains(_engine.targetValue)) {
        _startCompletionAnimation(_engine.targetValue);
      } else {
        _showChapterComplete();
      }
    } else if (_engine.gameOver) {
      _showGameOver();
    }
  }

  void _startCompletionAnimation(int value) {
    if (_completionAnimationPlaying || !mounted) return;
    final index = _engine.board.tiles.indexWhere((tile) => tile?.value == value);
    if (index < 0) {
      _showChapterComplete();
      return;
    }
    setState(() {
      _completionAnimationPlaying = true;
      _completionAnimationIndex = index;
      _completionAnimationImagePath = _engine.board.tiles[index]!.creature.imagePath;
    });
    _completionAnimationController..reset()..forward();
  }

  Widget _buildCompletionAnimation() {
    final index = _completionAnimationIndex;
    final imagePath = _completionAnimationImagePath;
    if (!_completionAnimationPlaying || index == null || imagePath == null) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const boardPadding = 8.0;
            const tileGap = 6.0;
            final tileSize =
                (constraints.maxWidth - boardPadding * 2 - tileGap * 3) / 4;
            final row = index ~/ 4;
            final column = index % 4;
            final startX = boardPadding + column * (tileSize + tileGap);
            final startY = boardPadding + row * (tileSize + tileGap);
            final startCenter = Offset(startX + tileSize / 2, startY + tileSize / 2);
            final boardCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
            return AnimatedBuilder(
              animation: _completionAnimationController,
              builder: (context, child) {
                final t = Curves.easeInOutCubic.transform(
                  _completionAnimationController.value,
                );
                final position = Offset.lerp(startCenter, boardCenter, t)!;
                final scale = 1 + t * 0.65;
                final opacity = 1 - t;
                return Positioned(
                  left: position.dx - tileSize * scale / 2,
                  top: position.dy - tileSize * scale / 2,
                  width: tileSize * scale,
                  height: tileSize * scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showEvolutionNotice(int value) {
    if (!mounted) return;
    setState(() {
      _evolutionValue = value;
      _evolutionCreatureName = _creatureNameForValue(value);
    });
  }

  String _creatureNameForValue(int value) {
    final creatures = switch (_engine.chapter) {
      GameChapter.ocean => Creature.chapter1Ocean,
      GameChapter.land => Creature.chapter2Land,
      GameChapter.sky => Creature.chapter3Sky,
      GameChapter.history => Creature.chapter4History,
      GameChapter.tech => Creature.chapter5Tech,
      GameChapter.universe => Creature.chapter6Universe,
    };
    for (final creature in creatures) {
      if (creature.value == value) return creature.name;
    }
    return '';
  }

  Future<bool> _reset() async {
    if (!mounted || _completionAnimationPlaying || _restartInProgress) {
      return false;
    }

    _restartInProgress = true;
    _gameSessionGeneration++;

    // Build the replacement board immediately. The old implementation waited
    // for the Firebase restart transaction before changing the UI, which made
    // a restart visibly stall while the callable completed.
    final oldEngine = _engine;
    final saveData = oldEngine.createSaveData();
    final replayLog = saveData['replayLog'];
    final replay = replayLog is Map
        ? Map<String, dynamic>.from(replayLog)
        : null;

    oldEngine.stopGameTimer();
    final newEngine = GameEngine(
      chapter: oldEngine.chapter,
      forceNewBoard: true,
      boardLifeActive: true,
    );

    setState(() {
      _engine = newEngine;
      _evolutionValue = null;
      _evolutionCreatureName = null;
      _firstSwapIndex = null;
      _dragStart = null;
      _swipeHandled = false;
      _toolMode = null;
      _pressedToolMode = null;
    });

    _engine.startGameTimer();
    _startUiRefreshTimer();
    _focusNode.requestFocus();

    // The replacement board is locally playable while Firebase performs
    // the atomic session replacement in the background.
    final restarted =
        await PlayerProgressService.instance.restartGameSession(
      _chapterNumber - 1,
      replayLog: replay,
    );

    if (restarted) {
      // restartGameSession refreshes the authoritative inventory after the
      // replacement session is created. The replacement engine was already
      // mounted for local-first responsiveness, so copy that refreshed
      // inventory into its existing ToolState before continuing.
      _engine.toolManager.refreshFromSavedProgress();

      // The replacement engine was created before Firebase returned the new
      // session ID, so its initial unbound autosave is intentionally rejected
      // by SaveManager. Now that restartGameSession has installed the new
      // authoritative session binding, persist THIS replacement board with
      // that binding. Do not rebind the old board snapshot: doing so would
      // resurrect the exact pre-restart board the user just replaced.
      await SaveManager.save(_engine.createSaveData());
    }

    if (!mounted) {
      _restartInProgress = false;
      return restarted;
    }

    if (!restarted) {
      // The server rejected the replacement session. Restore the previous
      // board only after the replacement engine has fully stopped so a queued
      // autosave cannot race and put the transient new board back on screen.
      newEngine.stopGameTimer();
      // The replacement engine autosaves immediately. Wait for that queued
      // write to finish, then restore the previous board snapshot so local
      // state cannot be left on the uncharged replacement board.
      await newEngine.flushLocalSave();
      await SaveManager.save(oldEngine.createSaveData());
      oldEngine.startGameTimer();
      setState(() {
        _engine = oldEngine;
      });
      _startUiRefreshTimer();
      _focusNode.requestFocus();
    }

    _restartInProgress = false;
    if (mounted) setState(() {});
    return restarted;
  }

  Future<void> _handleSystemBack() async {
    if (_handlingSystemBack || !mounted) return;
    _handlingSystemBack = true;

    final chapter = _engine.chapter.name;
    final sessionId = PlayerProgressService.instance.activeGameSessionId;
    final saveData = _engine.createSaveData();
    final replayLog = saveData['replayLog'];
    final replay = replayLog is Map
        ? Map<String, dynamic>.from(replayLog)
        : null;
    final wasGameOver = _engine.gameOver;
    final wasChapterComplete = _engine.chapterComplete;

    _engine.pauseGameTimer();
    _stopUiRefreshTimer();
    _allowSystemPop = true;

    if (wasChapterComplete) {
      Navigator.of(context).pop();
      _handlingSystemBack = false;
      return;
    }

    // Navigation must never wait for Firebase. The server settlement carries
    // the captured session id so a fast re-entry cannot settle the new session.
    if (sessionId != null) {
      if (wasGameOver) {
        unawaited(
          PlayerProgressService.instance.abandonGameSession(
            sessionId: sessionId,
            replayLog: replay,
          ),
        );
        unawaited(SaveManager.clearChapter(chapter));
      } else {
        // Wait for refund + active-session clearing before Home can refresh.
        await PlayerProgressService.instance.exitUnfinishedGameSession(
          sessionId: sessionId,
          replayLog: replay,
        );
      }
    }

    Navigator.of(context).pop();
    _handlingSystemBack = false;
  }

  Future<void> _showResetMenu() async {
    if (!mounted ||
        _completionAnimationPlaying ||
        _gameOverDialogShowing ||
        _chapterCompleteShowing) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('回首頁'),
              onTap: () => Navigator.of(context).pop('home'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('重玩'),
              onTap: () => Navigator.of(context).pop('restart'),
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('繼續'),
              onTap: () => Navigator.of(context).pop('continue'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null || action == 'continue') {
      return;
    }

    if (action == 'home') {
      final sessionId = PlayerProgressService.instance.activeGameSessionId;
      final saveData = _engine.createSaveData();
      final replayLog = saveData['replayLog'];
      final replay = replayLog is Map
          ? Map<String, dynamic>.from(replayLog)
          : null;
      _engine.pauseGameTimer();
      _stopUiRefreshTimer();
      if (sessionId != null) {
        // Wait for refund + active-session clearing before Home can refresh.
        await PlayerProgressService.instance.exitUnfinishedGameSession(
          sessionId: sessionId,
          replayLog: replay,
        );
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (action == 'restart') {
      final restarted = await _reset();
      if (restarted && mounted) {
        unawaited(AudioManager.instance.playChapterMusic(_engine.chapter));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restart the game. Please check your Life and try again.')),
        );
      }
    }
  }

  Future<void> _startTool(String mode) async {
    // Tool selection must never call resumeGameSession. A tool press is an
    // action inside the current game, not a new game entry, so it must not
    // consume another Life or wait for session re-entry.
    if (PlayerProgressService.instance.activeGameSessionId == null) return;
    if (!_engine.hasTools || _engine.gameOver || _engine.chapterComplete ||
        _gameOverDialogShowing || _chapterCompleteShowing ||
        _completionAnimationPlaying) {
      return;
    }
    final toolType = switch (mode) {
      'revive' => GameToolType.revive,
      'rewind' => GameToolType.timeRewind,
      'swap' => GameToolType.positionSwap,
      'duplicate' => GameToolType.duplicate,
      _ => null,
    };
    if (toolType == null) return;
    final toolState = _engine.toolManager.getTool(toolType);
    if (toolState == null) return;
    if (!toolState.canUse) {
      if (!mounted) return;
      if (mode == 'rewind') {
        await _showToolUnavailable('UNDO');
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToolsPage())).then((_) {
        if (!mounted) return;
        setState(() {});
      });
      return;
    }
    if (mode == 'rewind') {
      if (!_engine.canUseTimeRewind) {
        await _showToolUnavailable('UNDO');
        return;
      }
      if (_engine.useTimeRewind()) setState(() {});
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _toolMode = mode;
      _firstSwapIndex = null;
    });
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

  Future<void> _selectToolTile(int index) async {
    final mode = _toolMode;
    if (mode == null) return;
    final tile = _engine.board.tiles[index];
    final row = index ~/ 4;
    final column = index % 4;
    if (mode == 'duplicate') {
      if (_firstSwapIndex == null) {
        if (tile == null) return;
        setState(() => _firstSwapIndex = index);
        return;
      }
      final first = _firstSwapIndex!;
      if (first == index || tile != null) return;
      final changed = _engine.useDuplicate(first ~/ 4, first % 4, row, column);
      if (changed) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
      return;
    }
    if (tile == null) return;
    if (mode == 'revive') {
      if (_engine.useRevive(row, column)) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
      return;
    }
    if (mode == 'swap') {
      if (_firstSwapIndex == null) {
        setState(() => _firstSwapIndex = index);
        return;
      }
      final first = _firstSwapIndex!;
      if (first == index) return;
      final changed = _engine.usePositionSwap(first ~/ 4, first % 4, row, column);
      if (changed) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
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

  Future<void> _selectToolTile(int index) async {
    final mode = _toolMode;
    if (mode == null) return;
    final tile = _engine.board.tiles[index];
    final row = index ~/ 4;
    final column = index % 4;
    if (mode == 'duplicate') {
      if (_firstSwapIndex == null) {
        if (tile == null) return;
        setState(() => _firstSwapIndex = index);
        return;
      }
      final first = _firstSwapIndex!;
      if (first == index || tile != null) return;
      final changed = _engine.useDuplicate(first ~/ 4, first % 4, row, column);
      if (changed) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
      return;
    }
    if (tile == null) return;
    if (mode == 'revive') {
      if (_engine.useRevive(row, column)) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
      return;
    }
    if (mode == 'swap') {
      if (_firstSwapIndex == null) {
        setState(() => _firstSwapIndex = index);
        return;
      }
      final first = _firstSwapIndex!;
      if (first == index) return;
      final changed = _engine.usePositionSwap(first ~/ 4, first % 4, row, column);
      if (changed) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _showGameOver() async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    _engine.stopGameTimer();
    await AudioManager.instance.stopMusic();
    await AudioManager.instance.playSfx(GameSfx.gameOver);
    if (!mounted) return;
    final shouldRestart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Score: ${_engine.score}\nHighest: ${_engine.highestValue}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Home'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],

      ),
    );
    if (!mounted) return;
    _gameOverDialogShowing = false;
    if (shouldRestart == true) {
      final restarted = await _reset();
      if (restarted && mounted) {
        unawaited(AudioManager.instance.playChapterMusic(_engine.chapter));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restart the game. Please check your Life and try again.')),
        );
      }
    } else {
      final sessionId = PlayerProgressService.instance.activeGameSessionId;
      final saveData = _engine.createSaveData();
      final replayLog = saveData['replayLog'];
      final replay = replayLog is Map
          ? Map<String, dynamic>.from(replayLog)
          : null;
      final chapter = _engine.chapter.name;

      await SaveManager.clearChapter(chapter);
      if (!mounted) return;

      if (sessionId != null) {
        // Settle Game Over tool usage before returning to Home. Otherwise
        // Home can refresh the inventory before abandonGameSession finishes
        // and briefly show the pre-Game-Over balance.
        await PlayerProgressService.instance.abandonGameSession(
          sessionId: sessionId,
          replayLog: replay,
        );
        if (!mounted) return;
      }

      Navigator.of(context).pop();
    }
  }

  String _backgroundForHighest(int highestValue) {
    final backgrounds = switch (_engine.chapter) {
      GameChapter.ocean => _oceanBackgrounds,
      GameChapter.land => _landBackgrounds,
      GameChapter.sky => _skyBackgrounds,
      GameChapter.history => _historyBackgrounds,
      GameChapter.tech => _techBackgrounds,
      GameChapter.universe => _universeBackgrounds,
    };
    final index = highestValue <= 1
        ? 0
        : highestValue >= 2048
            ? 3
            : highestValue >= 128
                ? 2
                : highestValue >= 32
                    ? 1
                    : 0;
    return backgrounds[index];
  }

  String _creatureNameForValue(int value) {
    final creatures = switch (_engine.chapter) {
      GameChapter.ocean => Creature.chapter1Ocean,
      GameChapter.land => Creature.chapter2Land,
      GameChapter.sky => Creature.chapter3Sky,
      GameChapter.history => Creature.chapter4History,
      GameChapter.tech => Creature.chapter5Tech,
      GameChapter.universe => Creature.chapter6Universe,
    };
    for (final creature in creatures) {
      if (creature.value == value) return creature.name;
    }
    return '';
  }

  // Remaining UI and handlers are unchanged.
}