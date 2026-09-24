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
  Future<bool>? _completionVerificationFuture;
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
      case AppLifecycleState.resumed: _resumeGameplay(); break;
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
      if (_engine.gameOver && !_engine.chapterComplete) await _showGameOver();
      return;
    }
    _resumeGameplay();
    _focusNode.requestFocus();
    if (_engine.gameOver && !_engine.chapterComplete) await _showGameOver();
  }

  Future<bool> _ensureGameSession() {
    final existing = _gameSessionFuture;
    if (existing != null) return existing;
    final future = _createGameSession();
    _gameSessionFuture = future;
    future.whenComplete(() {
      if (identical(_gameSessionFuture, future)) _gameSessionFuture = null;
    });
    return future;
  }

  Future<bool> _createGameSession() async {
    final generation = _gameSessionGeneration;
    try {
      final progress = PlayerProgressService.instance;
      if (!progress.loadedFromServer) await progress.refresh();
      if (!mounted || generation != _gameSessionGeneration) return false;
      final activeSessionId = progress.activeGameSessionId;
      final activeChapter = progress.activeGameChapterIndex;
      if (activeSessionId != null) {
        if (activeChapter != _chapterNumber - 1) return false;
        final entered = await progress.resumeGameSession(_chapterNumber - 1);
        if (!entered || !mounted || generation != _gameSessionGeneration) return false;
        final saved = SaveManager.loadCached(chapter: _engine.chapter.name);
        final hasPlayableLocalBoard = saved != null &&
            saved['gameSessionId'] == progress.activeGameSessionId &&
            saved['gameOver'] != true && saved['chapterComplete'] != true &&
            saved['tiles'] is List && (saved['tiles'] as List).length == 16;
        await ToolManager.refreshInventory();
        if (!mounted || generation != _gameSessionGeneration) return false;
        _engine.stopGameTimer();
        _engine = GameEngine(
          chapter: _engine.chapter,
          forceNewBoard: !hasPlayableLocalBoard,
          boardLifeActive: true,
        );
        return true;
      }
      if (_engine.gameOver || _engine.chapterComplete) return false;
      // Build the exact new local board first. Its initialTiles are sent with
      // the background session transaction so the server can bind replay
      // validation to the board that was actually presented to the player.
      final newEngine = GameEngine(
        chapter: _engine.chapter,
        forceNewBoard: true,
        boardLifeActive: false,
      );
      final newSave = newEngine.createSaveData();
      final newReplay = newSave['replayLog'];
      final initialTiles = newReplay is Map && newReplay['initialTiles'] is List
          ? List<dynamic>.from(newReplay['initialTiles'] as List)
          : const <dynamic>[];
      // startGameSession() consumes the Life locally and starts the
      // Firebase transaction in the background. Do not await the network
      // transaction here: the new board must become playable immediately.
      final started = await progress.startGameSession(
        _chapterNumber - 1,
        initialTiles: initialTiles,
      );
      if (!started || !mounted || generation != _gameSessionGeneration) return false;
      _engine.stopGameTimer();
      newEngine.startGameTimer();
      _engine = newEngine;
      newEngine.setBoardLifeActiveForSession();
      // Tool inventory is authoritative but must not delay game entry. Refresh
      // it in the background and update the already-mounted engine when ready.
      unawaited(_refreshMountedToolInventory(generation));
      return true;
    } catch (error) {
      debugPrint('Failed to create game session: $error');
      return false;
    }
  }

  Future<void> _refreshMountedToolInventory(int generation) async {
    await ToolManager.refreshInventory();
    if (!mounted || generation != _gameSessionGeneration) return;
    _engine.toolManager.refreshFromSavedProgress();
    setState(() {});
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      LifeManager.tickRegeneration();
      if (mounted) setState(() {});
    });
  }
  void _stopUiRefreshTimer() { _uiRefreshTimer?.cancel(); _uiRefreshTimer = null; }
  void _handleCompletionAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _showChapterComplete();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_gameOverDialogShowing || _chapterCompleteShowing || _completionAnimationPlaying || _toolMode != null) return KeyEventResult.handled;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 'up', LogicalKeyboardKey.arrowDown => 'down',
      LogicalKeyboardKey.arrowLeft => 'left', LogicalKeyboardKey.arrowRight => 'right', _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;
    _move(direction); return KeyEventResult.handled;
  }
  void _handleDragStart(DragStartDetails details) {
    if (_gameOverDialogShowing || _chapterCompleteShowing || _completionAnimationPlaying || _toolMode != null) return;
    _dragStart = details.localPosition; _swipeHandled = false;
  }
  void _handleDragUpdate(DragUpdateDetails details) {
    if (_gameOverDialogShowing || _chapterCompleteShowing || _toolMode != null || _swipeHandled || _dragStart == null) return;
    final delta = details.localPosition - _dragStart!;
    if (delta.distance < _swipeThreshold) return;
    final direction = delta.dx.abs() > delta.dy.abs() ? (delta.dx < 0 ? 'left' : 'right') : (delta.dy < 0 ? 'up' : 'down');
    _swipeHandled = true; _move(direction);
  }
  void _handleDragEnd(DragEndDetails details) { _dragStart = null; _swipeHandled = false; }

  void _move(String direction) {
    if (_gameOverDialogShowing || _chapterCompleteShowing || _completionAnimationPlaying || _toolMode != null) return;
    bool changed;
    switch (direction) { case 'up': changed = _engine.moveUp(); break; case 'down': changed = _engine.moveDown(); break; case 'left': changed = _engine.moveLeft(); break; case 'right': changed = _engine.moveRight(); break; default: changed = false; }
    if (!changed) return;
    final newEvolutionValues = _engine.newEvolutionValuesThisMove;
    final mergedValues = _engine.board.lastMergedValues;
    if (mergedValues.isNotEmpty) unawaited(CreatureCollectionService.discover(_engine.chapter.name, mergedValues));
    if (newEvolutionValues.isNotEmpty) AudioManager.instance.playSfx(GameSfx.tileMerge); else AudioManager.instance.playSfx(GameSfx.tileMove);
    if (mounted) setState(() {});
    if (newEvolutionValues.isNotEmpty) { _showEvolutionNotice(newEvolutionValues.last); HapticService.evolutionImpact(); }
    if (_engine.chapterComplete) {
      if (newEvolutionValues.contains(_engine.targetValue)) _startCompletionAnimation(_engine.targetValue); else _showChapterComplete();
    } else if (_engine.gameOver) _showGameOver();
  }

  void _startCompletionAnimation(int value) {
    if (_completionAnimationPlaying || !mounted) return;
    final index = _engine.board.tiles.indexWhere((tile) => tile?.value == value);
    if (index < 0) { _showChapterComplete(); return; }
    final progress = PlayerProgressService.instance;
    final saveData = _engine.createSaveData();
    final replayLog = saveData['replayLog'];
    if (progress.activeGameSessionId == null || progress.activeGameChapterIndex != _chapterNumber - 1 || replayLog is! Map) {
      _showChapterComplete();
      return;
    }
    // Start the server verification immediately. The 280ms visual animation
    // now runs in parallel with Firebase validation instead of after it.
    _completionVerificationFuture = progress.completeChapter(
      chapterIndex: _chapterNumber - 1,
      replayLog: Map<String, dynamic>.from(replayLog),
    );
    setState(() {
      _completionAnimationPlaying = true;
      _completionAnimationIndex = index;
      _completionAnimationImagePath = _engine.board.tiles[index]!.creature.imagePath;
    });
    _completionAnimationController..reset()..forward();
  }

  Widget _buildCompletionAnimation() {
    final index = _completionAnimationIndex; final imagePath = _completionAnimationImagePath;
    if (!_completionAnimationPlaying || index == null || imagePath == null) return const SizedBox.shrink();
    return Positioned.fill(child: IgnorePointer(child: LayoutBuilder(builder: (context, constraints) {
      const boardPadding = 8.0; const tileGap = 6.0;
      final tileSize = (constraints.maxWidth - boardPadding * 2 - tileGap * 3) / 4;
      final row = index ~/ 4; final column = index % 4;
      final startX = boardPadding + column * (tileSize + tileGap); final startY = boardPadding + row * (tileSize + tileGap);
      final startCenter = Offset(startX + tileSize / 2, startY + tileSize / 2); final boardCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
      return AnimatedBuilder(animation: _completionAnimationController, builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(_completionAnimationController.value);
        final center = Offset.lerp(startCenter, boardCenter, progress)!; final scale = 1 + progress * 3.0;
        return Transform.translate(offset: center - boardCenter, child: Transform.scale(scale: scale, child: child));
      }, child: Align(alignment: Alignment.center, child: SizedBox(width: tileSize, height: tileSize, child: Image.asset(imagePath, fit: BoxFit.contain))));
    })));
  }

  void _showEvolutionNotice(int value) { if (!mounted) return; setState(() { _evolutionValue = value; _evolutionCreatureName = _creatureNameForValue(value); }); }
  String _creatureNameForValue(int value) {
    final creatures = switch (_engine.chapter) { GameChapter.ocean => Creature.chapter1Ocean, GameChapter.land => Creature.chapter2Land, GameChapter.sky => Creature.chapter3Sky, GameChapter.history => Creature.chapter4History, GameChapter.tech => Creature.chapter5Tech, GameChapter.universe => Creature.chapter6Universe };
    for (final creature in creatures) { if (creature.value == value) return creature.name; } return '';
  }

  Future<bool> _reset() async {
    if (!mounted || _completionAnimationPlaying || _restartInProgress) return false;
    _restartInProgress = true; _gameSessionGeneration++;
    final oldEngine = _engine; final previousSessionId = PlayerProgressService.instance.activeGameSessionId;
    final saveData = oldEngine.createSaveData(); final replayLog = saveData['replayLog']; final replay = replayLog is Map ? Map<String, dynamic>.from(replayLog) : null;
    oldEngine.stopGameTimer();
    final newEngine = GameEngine(chapter: oldEngine.chapter, forceNewBoard: true, boardLifeActive: true);
    setState(() { _engine = newEngine; _evolutionValue = null; _evolutionCreatureName = null; _firstSwapIndex = null; _dragStart = null; _swipeHandled = false; _toolMode = null; _pressedToolMode = null; });
    _engine.startGameTimer(); _startUiRefreshTimer(); _focusNode.requestFocus();
    final newReplayData = newEngine.createSaveData()['replayLog'];
    final initialTiles = newReplayData is Map && newReplayData['initialTiles'] is List ? List<dynamic>.from(newReplayData['initialTiles'] as List) : const <dynamic>[];
    final restarted = await PlayerProgressService.instance.restartGameSession(_chapterNumber - 1, replayLog: replay, initialTiles: initialTiles);
    if (restarted) {
      _engine.toolManager.refreshFromSavedProgress();
      final newSessionId = PlayerProgressService.instance.activeGameSessionId;
      if (newSessionId != null) await SaveManager.rebindCachedGameSession(chapter: oldEngine.chapter.name, previousSessionId: previousSessionId, newSessionId: newSessionId);
    }
    if (!mounted) { _restartInProgress = false; return restarted; }
    if (!restarted) {
      newEngine.stopGameTimer(); await newEngine.flushLocalSave(); await SaveManager.save(oldEngine.createSaveData()); oldEngine.startGameTimer();
      setState(() { _engine = oldEngine; }); _startUiRefreshTimer(); _focusNode.requestFocus();
    }
    _restartInProgress = false; if (mounted) setState(() {}); return restarted;
  }

  Future<void> _handleSystemBack() async {
    if (_handlingSystemBack || !mounted) return; _handlingSystemBack = true;
    final chapter = _engine.chapter.name; final sessionId = PlayerProgressService.instance.activeGameSessionId;
    final saveData = _engine.createSaveData(); final replayLog = saveData['replayLog']; final replay = replayLog is Map ? Map<String, dynamic>.from(replayLog) : null;
    final wasGameOver = _engine.gameOver; final wasChapterComplete = _engine.chapterComplete;
    _engine.pauseGameTimer(); _stopUiRefreshTimer(); _allowSystemPop = true;
    if (wasChapterComplete) { Navigator.of(context).pop(); _handlingSystemBack = false; return; }
    if (sessionId != null) {
      if (wasGameOver) { await PlayerProgressService.instance.abandonGameSession(sessionId: sessionId, replayLog: replay); await SaveManager.clearChapter(chapter); }
      else await PlayerProgressService.instance.exitUnfinishedGameSession(sessionId: sessionId, replayLog: replay);
    }
    Navigator.of(context).pop(); _handlingSystemBack = false;
  }

  Future<void> _showResetMenu() async {
    if (!mounted || _completionAnimationPlaying || _gameOverDialogShowing || _chapterCompleteShowing) return;
    final action = await showModalBottomSheet<String>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.home_outlined), title: const Text('回首頁'), onTap: () => Navigator.of(context).pop('home')),
      ListTile(leading: const Icon(Icons.refresh), title: const Text('重玩'), onTap: () => Navigator.of(context).pop('restart')),
      ListTile(leading: const Icon(Icons.play_arrow), title: const Text('繼續'), onTap: () => Navigator.of(context).pop('continue')),
    ])));
    if (!mounted || action == null || action == 'continue') return;
    if (action == 'home') {
      final sessionId = PlayerProgressService.instance.activeGameSessionId; final saveData = _engine.createSaveData(); final replayLog = saveData['replayLog']; final replay = replayLog is Map ? Map<String, dynamic>.from(replayLog) : null;
      _engine.pauseGameTimer(); _stopUiRefreshTimer();
      if (sessionId != null) await PlayerProgressService.instance.exitUnfinishedGameSession(sessionId: sessionId, replayLog: replay);
      if (mounted) Navigator.of(context).pop(); return;
    }
    if (action == 'restart') {
      final restarted = await _reset();
      if (restarted && mounted) unawaited(AudioManager.instance.playChapterMusic(_engine.chapter));
      else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to restart the game. Please check your Life and try again.')));
    }
  }

  Future<void> _startTool(String mode) async {
    if (PlayerProgressService.instance.activeGameSessionId == null) return;
    if (!_engine.hasTools || _engine.gameOver || _engine.chapterComplete || _gameOverDialogShowing || _chapterCompleteShowing || _completionAnimationPlaying) return;
    final toolType = switch (mode) { 'revive' => GameToolType.revive, 'rewind' => GameToolType.timeRewind, 'swap' => GameToolType.positionSwap, 'duplicate' => GameToolType.duplicate, _ => null };
    if (toolType == null) return; final toolState = _engine.toolManager.getTool(toolType); if (toolState == null) return;
    if (!toolState.canUse) { if (!mounted) return; if (mode == 'rewind') { await _showToolUnavailable('UNDO'); return; } Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToolsPage())).then((_) async { await ToolManager.refreshInventory(); if (!mounted) return; _engine.toolManager.refreshFromSavedProgress(); setState(() {}); }); return; }
    if (mode == 'rewind') { if (!_engine.canUseTimeRewind) { await _showToolUnavailable('UNDO'); return; } if (_engine.useTimeRewind()) setState(() {}); _focusNode.requestFocus(); return; }
    setState(() { _toolMode = mode; _firstSwapIndex = null; });
  }
  Future<void> _showToolUnavailable(String toolName) async {
    if (!mounted) return; await showModalBottomSheet<void>(context: context, builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.ondemand_video_outlined), title: Text('取得 $toolName'), subtitle: const Text('可觀看 Rewarded Ad 取得額外使用次數'), onTap: () => Navigator.pop(context)),
      ListTile(leading: const Icon(Icons.store_outlined), title: const Text('前往商城'), onTap: () { Navigator.pop(context); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToolsPage())); }),
    ])));
  }
  Future<void> _selectToolTile(int index) async {
    final mode = _toolMode; if (mode == null) return; final tile = _engine.board.tiles[index]; final row = index ~/ 4; final column = index % 4;
    if (mode == 'duplicate') { if (_firstSwapIndex == null) { if (tile == null) return; setState(() => _firstSwapIndex = index); return; } final first = _firstSwapIndex!; if (first == index || tile != null) return; if (_engine.useDuplicate(first ~/ 4, first % 4, row, column)) { setState(() { _toolMode = null; _firstSwapIndex = null; }); _focusNode.requestFocus(); } return; }
    if (tile == null) return;
    if (mode == 'revive') { if (_engine.useRevive(row, column)) { setState(() { _toolMode = null; _firstSwapIndex = null; }); _focusNode.requestFocus(); } return; }
    if (mode == 'swap') { if (_firstSwapIndex == null) { setState(() => _firstSwapIndex = index); return; } final first = _firstSwapIndex!; if (first == index) return; if (_engine.usePositionSwap(first ~/ 4, first % 4, row, column)) { setState(() { _toolMode = null; _firstSwapIndex = null; }); _focusNode.requestFocus(); } }
  }

  Future<void> _showGameOver() async {
    if (_gameOverDialogShowing || !mounted) return; _gameOverDialogShowing = true; _engine.stopGameTimer(); await AudioManager.instance.stopMusic(); await AudioManager.instance.playSfx(GameSfx.gameOver); if (!mounted) return;
    final shouldRestart = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(title: const Text('Game Over'), content: Text('Score: ${_engine.score}\nHighest: ${_engine.highestValue}'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Home')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Restart'))]));
    if (!mounted) return; _gameOverDialogShowing = false;
    if (shouldRestart == true) { final restarted = await _reset(); if (restarted && mounted) unawaited(AudioManager.instance.playChapterMusic(_engine.chapter)); else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to restart the game. Please check your Life and try again.'))); }
    else {
      final sessionId = PlayerProgressService.instance.activeGameSessionId; final saveData = _engine.createSaveData(); final replayLog = saveData['replayLog']; final replay = replayLog is Map ? Map<String, dynamic>.from(replayLog) : null; final chapter = _engine.chapter.name;
      if (sessionId != null) await PlayerProgressService.instance.abandonGameSession(sessionId: sessionId, replayLog: replay);
      await SaveManager.clearChapter(chapter); if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  String _backgroundForHighest(int highestValue) {
    final backgrounds = switch (_engine.chapter) { GameChapter.ocean => _oceanBackgrounds, GameChapter.land => _landBackgrounds, GameChapter.sky => _skyBackgrounds, GameChapter.history => _historyBackgrounds, GameChapter.tech => _techBackgrounds, GameChapter.universe => _universeBackgrounds };
    final stage = highestValue > 0 ? (highestValue.bitLength - 1) : 1;
    final backgroundIndex = switch (_engine.chapter) { GameChapter.ocean => stage >= 10 ? 3 : stage >= 7 ? 2 : stage >= 4 ? 1 : 0, GameChapter.land => stage >= 12 ? 3 : stage >= 9 ? 2 : stage >= 5 ? 1 : 0, GameChapter.sky => stage >= 13 ? 3 : stage >= 11 ? 2 : stage >= 5 ? 1 : 0, GameChapter.history => stage >= 14 ? 3 : stage >= 12 ? 2 : stage >= 7 ? 1 : 0, GameChapter.tech => stage >= 13 ? 3 : stage >= 9 ? 2 : stage >= 5 ? 1 : 0, GameChapter.universe => stage >= 13 ? 3 : stage >= 7 ? 2 : stage >= 4 ? 1 : 0 };
    return backgrounds[backgroundIndex];
  }
  String get _chapterTitle => switch (_engine.chapter) { GameChapter.ocean => 'Ocean Chapter', GameChapter.land => 'Land Chapter', GameChapter.sky => 'Sky Chapter', GameChapter.history => 'History Chapter', GameChapter.tech => 'Technology Chapter', GameChapter.universe => 'Universe Chapter' };
  int get _chapterNumber => switch (_engine.chapter) { GameChapter.ocean => 1, GameChapter.land => 2, GameChapter.sky => 3, GameChapter.history => 4, GameChapter.tech => 5, GameChapter.universe => 6 };

  Future<void> _showChapterComplete() async {
    if (_chapterCompleteShowing || !mounted) return; _chapterCompleteShowing = true; _engine.stopGameTimer();
    final progress = PlayerProgressService.instance;
    if (progress.activeGameSessionId == null || progress.activeGameChapterIndex != _chapterNumber - 1) { _chapterCompleteShowing = false; return; }
    final completedChapter = _engine.chapter;
    bool completionAccepted;
    final pending = _completionVerificationFuture;
    if (pending != null) {
      completionAccepted = await pending;
      _completionVerificationFuture = null;
    } else {
      final saveData = _engine.createSaveData(); final replayLog = saveData['replayLog'];
      if (replayLog is! Map) { _chapterCompleteShowing = false; return; }
      completionAccepted = await progress.completeChapter(chapterIndex: _chapterNumber - 1, replayLog: Map<String, dynamic>.from(replayLog));
    }
    if (!completionAccepted) { _chapterCompleteShowing = false; return; }
    await AudioManager.instance.stopMusic(); unawaited(AudioManager.instance.playSfx(GameSfx.chapterUnlock)); if (!mounted) return;
    _chapterCompleteShowing = false;
    final result = await Navigator.of(context).push<String>(MaterialPageRoute<String>(builder: (context) => _ChapterCompletePage(chapter: completedChapter, score: _engine.score, highestValue: _engine.highestValue, onNextChapter: () => Navigator.of(context).pop('next'), onHome: () => Navigator.of(context).pop('home'))));
    if (!mounted) return;
    _completionAnimationPlaying = false; _completionAnimationIndex = null; _completionAnimationImagePath = null;
    if (result == 'home') { Navigator.of(context).pop(); return; }
    if (result != 'next') { _focusNode.requestFocus(); return; }
    switch (completedChapter) { case GameChapter.ocean: _startChapter(GameChapter.land, forceNewBoard: true); break; case GameChapter.land: _startChapter(GameChapter.sky, forceNewBoard: true); break; case GameChapter.sky: _startChapter(GameChapter.history, forceNewBoard: true); break; case GameChapter.history: _startChapter(GameChapter.tech, forceNewBoard: true); break; case GameChapter.tech: _startChapter(GameChapter.universe, forceNewBoard: true); break; case GameChapter.universe: _focusNode.requestFocus(); break; }
  }

  Future<void> _startChapter(GameChapter chapter, {bool forceNewBoard = false}) async {
    if (!mounted) return; final previewEngine = GameEngine(chapter: chapter, forceNewBoard: true, boardLifeActive: false);
    final previewReplay = previewEngine.createSaveData()['replayLog'];
    final initialTiles = previewReplay is Map && previewReplay['initialTiles'] is List ? List<dynamic>.from(previewReplay['initialTiles'] as List) : const <dynamic>[];
    final started = await PlayerProgressService.instance.restartGameSession(chapter.index, initialTiles: initialTiles); if (!started || !mounted) return; await ToolManager.refreshInventory(); if (!mounted) return;
    final newEngine = GameEngine(chapter: chapter, forceNewBoard: forceNewBoard, boardLifeActive: true);
    setState(() { _engine = newEngine; _toolMode = null; _firstSwapIndex = null; _dragStart = null; _swipeHandled = false; _evolutionValue = null; _evolutionCreatureName = null; });
    _engine.startGameTimer(); _startUiRefreshTimer(); unawaited(AudioManager.instance.playChapterMusic(chapter)); _focusNode.requestFocus();
  }

  String _toolLabel(GameToolType type) => switch (type) { GameToolType.revive => 'REMOVE', GameToolType.timeRewind => 'UNDO', GameToolType.positionSwap => 'SWAP', GameToolType.duplicate => 'DUPLICATE' };
  String _toolModeForType(GameToolType type) => switch (type) { GameToolType.revive => 'revive', GameToolType.timeRewind => 'rewind', GameToolType.positionSwap => 'swap', GameToolType.duplicate => 'duplicate' };
  String _toolImagePath(String mode, {required bool pressed}) => switch (mode) { 'rewind' => pressed ? 'assets/tools/tool_undo_pressed.png' : 'assets/tools/tool_undo.png', 'swap' => pressed ? 'assets/tools/tool_swap_pressed.png' : 'assets/tools/tool_swap.png', 'revive' => pressed ? 'assets/tools/tool_remove_pressed.png' : 'assets/tools/tool_remove.png', 'duplicate' => pressed ? 'assets/tools/tool_duplicate_pressed.png' : 'assets/tools/tool_duplicate.png', _ => '' };
  Widget _buildToolButton(GameToolType type) {
    final mode = _toolModeForType(type); final matching = _engine.toolManager.tools.where((state) => state.tool.type == type); final state = matching.isEmpty ? null : matching.first; final unlocked = state != null; final enabled = unlocked && state.canUse && switch (type) { GameToolType.revive => _engine.canUseRevive, GameToolType.timeRewind => _engine.canUseTimeRewind, GameToolType.positionSwap => _engine.canUsePositionSwap, GameToolType.duplicate => _engine.canUseDuplicate };
    final selected = _toolMode == mode; final pressed = _pressedToolMode == mode; final opacity = selected ? 0.45 : (unlocked ? 1.0 : 0.35); final canOpenShop = unlocked && !state.canUse; final canTap = selected || enabled || canOpenShop || mode == 'rewind';
    return GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: canTap ? (_) { if (mounted) setState(() => _pressedToolMode = mode); } : null, onTapUp: canTap ? (_) { if (!mounted) return; setState(() => _pressedToolMode = null); if (selected) { unawaited(AudioManager.instance.playSfx(GameSfx.buttonCancel)); setState(() { _toolMode = null; _firstSwapIndex = null; _pressedToolMode = null; }); _focusNode.requestFocus(); } else { unawaited(AudioManager.instance.playSfx(GameSfx.toolSelect)); unawaited(_startTool(mode)); } } : null, onTapCancel: canTap ? () { if (mounted) setState(() => _pressedToolMode = null); } : null, child: Opacity(opacity: opacity, child: SizedBox(height: 112, child: Stack(alignment: Alignment.center, children: [Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 76, height: 72, child: Image.asset(_toolImagePath(mode, pressed: pressed), fit: BoxFit.contain)), const SizedBox(height: 1), Text(selected ? 'CANCEL' : _toolLabel(type), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)), const SizedBox(height: 1), Text(state == null ? '?' : (LifeManager.isGoldenMember && type == GameToolType.timeRewind ? '∞' : '${state.usesRemaining}'), style: const TextStyle(fontSize: 8))]), if (!unlocked) const Positioned(top: 4, child: Icon(Icons.lock, size: 25)), if (selected) const Positioned(top: 2, child: Text('CANCEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))) ]))));
  }
  Widget _buildEvolutionNotice() { final value = _evolutionValue ?? _engine.highestEvolutionValue; final name = _evolutionCreatureName ?? _creatureNameForValue(value); if (name.isEmpty) return const SizedBox.shrink(); return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withValues(alpha: 0.68), border: Border.all(color: Colors.white.withValues(alpha: 0.45))), child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white))); }
  String _formatDuration(Duration duration) { final totalSeconds = duration.inSeconds; final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'; }

  @override
  Widget build(BuildContext context) {
    final background = _backgroundForHighest(_engine.highestValue); final l10n = AppLocalizations.of(context)!; final lifeCount = LifeManager.lifeCount; final lifeRemaining = LifeManager.regenerationRemaining; final lifeCountdown = lifeRemaining == null ? '' : ' (${_formatDuration(lifeRemaining)})';
    return PopScope<void>(canPop: _allowSystemPop, onPopInvokedWithResult: (didPop, result) { if (didPop || _allowSystemPop) return; unawaited(_handleSystemBack()); }, child: Scaffold(appBar: AppBar(title: Text(_chapterTitle), actions: []), body: SafeArea(child: Focus(autofocus: true, focusNode: _focusNode, onKeyEvent: _handleKey, child: GestureDetector(onPanStart: _handleDragStart, onPanUpdate: _handleDragUpdate, onPanEnd: _handleDragEnd, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Score ${_engine.score}', style: Theme.of(context).textTheme.titleMedium), Text('Best ${_engine.bestScore}', style: Theme.of(context).textTheme.titleMedium)]), const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${l10n.life} ${lifeCount < 0 ? '∞' : lifeCount}$lifeCountdown', style: Theme.of(context).textTheme.titleMedium), Row(mainAxisSize: MainAxisSize.min, children: [Text('${l10n.gameTime} ${_engine.formattedGameTime}', style: Theme.of(context).textTheme.titleMedium), IconButton(onPressed: _completionAnimationPlaying ? null : () { unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick)); _showResetMenu(); }, tooltip: 'Reset', visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32), icon: const Icon(Icons.refresh, size: 20))])]), const SizedBox(height: 12),
      Text(_toolMode == null ? 'Highest: ${_engine.highestValue} / ${_engine.targetValue}' : 'Select a tile for ${_toolMode == 'swap' ? 'Swap' : _toolMode == 'duplicate' ? 'Duplicate' : 'REMOVE'}', style: Theme.of(context).textTheme.bodyLarge), const SizedBox(height: 10), _buildEvolutionNotice(),
      AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(fit: StackFit.expand, children: [Image.asset(background, fit: BoxFit.cover), Container(color: Colors.black.withValues(alpha: 0.18)), GridView.builder(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.all(8), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6), itemCount: 16, itemBuilder: (context, index) { final tile = _engine.board.tiles[index]; final selected = _firstSwapIndex == index; return GestureDetector(onTap: () => unawaited(_selectToolTile(index)), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: selected ? Border.all(width: 3, color: Colors.yellow) : null, color: tile == null ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.82)), padding: EdgeInsets.all(_engine.chapter == GameChapter.universe ? 2 : 6), child: tile == null ? const SizedBox.shrink() : Image.asset(tile.creature.imagePath, fit: BoxFit.contain))); }), _buildCompletionAnimation()]))), const SizedBox(height: 12), Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Row(children: [Expanded(child: _buildToolButton(GameToolType.timeRewind)), Expanded(child: _buildToolButton(GameToolType.positionSwap)), Expanded(child: _buildToolButton(GameToolType.revive)), Expanded(child: _buildToolButton(GameToolType.duplicate))]))
    ]))))))));
  }
}

class _ChapterCompletePage extends StatelessWidget {
  const _ChapterCompletePage({required this.chapter, required this.score, required this.highestValue, required this.onNextChapter, required this.onHome});
  final GameChapter chapter; final int score; final int highestValue; final VoidCallback onNextChapter; final VoidCallback onHome;
  String get _background => switch (chapter) { GameChapter.ocean => 'assets/backgrounds/chapter_01_ocean/ocean_chapter_complete.jpg', GameChapter.land => 'assets/backgrounds/chapter_02_land/land_chapter_complete.jpg', GameChapter.sky => 'assets/backgrounds/chapter_03_sky/sky_chapter_complete.jpg', GameChapter.history => 'assets/backgrounds/chapter_04_history/chapter_04_history_complete.png', GameChapter.tech => 'assets/backgrounds/chapter_05_tech/tech_complete.png', GameChapter.universe => 'assets/backgrounds/chapter_06_universe/universe_chapter_complete.jpg' };
  String get _title => switch (chapter) { GameChapter.ocean => 'Ocean Restored', GameChapter.land => 'Land Restored', GameChapter.sky => 'Sky Restored', GameChapter.history => 'History Restored', GameChapter.tech => 'Technology Restored', GameChapter.universe => 'Universe Restored' };
  @override Widget build(BuildContext context) => Scaffold(body: Stack(fit: StackFit.expand, children: [Image.asset(_background, fit: BoxFit.cover), Container(color: Colors.black.withValues(alpha: 0.18)), SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [const Spacer(), Text(_title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 8, color: Colors.black)])), const SizedBox(height: 10), Text('Score $score    Highest $highestValue', style: const TextStyle(color: Colors.white, fontSize: 16)), const Spacer(), Padding(padding: const EdgeInsets.all(24), child: SizedBox(width: double.infinity, child: Column(children: [SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick)); onNextChapter(); }, child: const Text('Next Chapter'))), const SizedBox(height: 12), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick)); onHome(); }, child: const Text('Home')))])))])))]));
}
