import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/creature.dart';
import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import '../services/game_engine.dart';
import '../services/audio_manager.dart';
import '../services/haptic_service.dart';
import '../../screens/shop_page.dart';
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

  static const double _swipeThreshold = 30;

  // ------------------------------------------------------------
  // Chapter 1 Ocean
  // ------------------------------------------------------------

  static const List<String> _oceanBackgrounds = [
    'assets/backgrounds/chapter_01_ocean/ocean_background_01_primordial.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_02_shallow_sea.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_03_coral_reef.jpg',
    'assets/backgrounds/chapter_01_ocean/ocean_background_04_deep_ocean.jpg',
  ];

  // ------------------------------------------------------------
  // Chapter 2 Land
  // ------------------------------------------------------------

  static const List<String> _landBackgrounds = [
    'assets/backgrounds/chapter_02_land/land_background_01_primordial.jpg',
    'assets/backgrounds/chapter_02_land/land_background_02_forest.jpg',
    'assets/backgrounds/chapter_02_land/land_background_03_jungle.jpg',
    'assets/backgrounds/chapter_02_land/land_background_04_ancient_land.jpg',
  ];

  // ------------------------------------------------------------
  // Chapter 3 Sky
  // ------------------------------------------------------------

  static const List<String> _skyBackgrounds = [
    'assets/backgrounds/chapter_03_sky/sky_background_01_low_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_02_mid_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_03_high_altitude.jpg',
    'assets/backgrounds/chapter_03_sky/sky_background_04_space.jpg',
  ];

  // ------------------------------------------------------------
  // Chapter 4 History
  // ------------------------------------------------------------

  static const List<String> _historyBackgrounds = [
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_01.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_02.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_03.png',
    'assets/backgrounds/chapter_04_history/chapter_04_history_bg_04.png',
  ];

  // ------------------------------------------------------------
  // Chapter 5 Technology
  // ------------------------------------------------------------

  static const List<String> _techBackgrounds = [
    'assets/backgrounds/chapter_05_tech/tech_01_electronic_age.png',
    'assets/backgrounds/chapter_05_tech/tech_02_ai_robot.png',
    'assets/backgrounds/chapter_05_tech/tech_03_future_city.png',
    'assets/backgrounds/chapter_05_tech/tech_04_space_civilization.png',
  ];

  // ------------------------------------------------------------
  // Chapter 6 Universe
  // ------------------------------------------------------------

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
      if (!mounted) {
        return;
      }

      _focusNode.requestFocus();

      _resumeGameplay();

      AudioManager.instance.initialize().then((_) {
        if (mounted) {
          AudioManager.instance.playChapterMusic(_engine.chapter);
        }
      });

      if (_engine.gameOver && !_engine.chapterComplete) {
        _showGameOver();
      }
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

    if (!_engine.gameOver && !_engine.chapterComplete) {
      _engine.startGameTimer();
    }

    _startUiRefreshTimer();

    if (mounted) {
      setState(() {});
    }
  }

  void _startUiRefreshTimer() {
    _uiRefreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _engine.updateLifeFromRealTime();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopUiRefreshTimer() {
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
  }

  void _handleCompletionAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    // Keep the final enlarged creature visible while the
    // Chapter Complete transition is being prepared.
    _showChapterComplete();
  }

  // ============================================================
  // Keyboard
  // ============================================================

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _completionAnimationPlaying ||
        _toolMode != null) {
      return KeyEventResult.handled;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 'up',
      LogicalKeyboardKey.arrowDown => 'down',
      LogicalKeyboardKey.arrowLeft => 'left',
      LogicalKeyboardKey.arrowRight => 'right',
      _ => null,
    };

    if (direction == null) {
      return KeyEventResult.ignored;
    }

    _move(direction);

    return KeyEventResult.handled;
  }

  // ============================================================
  // Swipe
  // ============================================================

  void _handleDragStart(DragStartDetails details) {
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _completionAnimationPlaying ||
        _toolMode != null) {
      return;
    }

    _dragStart = details.localPosition;
    _swipeHandled = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _toolMode != null ||
        _swipeHandled ||
        _dragStart == null) {
      return;
    }

    final delta = details.localPosition - _dragStart!;

    if (delta.distance < _swipeThreshold) {
      return;
    }

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

  // ============================================================
  // Move
  // ============================================================

  void _move(String direction) {
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _completionAnimationPlaying ||
        _toolMode != null) {
      return;
    }

    bool changed;

    switch (direction) {
      case 'up':
        changed = _engine.moveUp();
        break;
      case 'down':
        changed = _engine.moveDown();
        break;
      case 'left':
        changed = _engine.moveLeft();
        break;
      case 'right':
        changed = _engine.moveRight();
        break;
      default:
        changed = false;
    }

    if (!changed) {
      return;
    }

    final newEvolutionValues = _engine.newEvolutionValuesThisMove;

    if (newEvolutionValues.isNotEmpty) {
      AudioManager.instance.playSfx(GameSfx.tileMerge);
    } else {
      AudioManager.instance.playSfx(GameSfx.tileMove);
    }

    if (mounted) {
      setState(() {});
    }

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
    if (_completionAnimationPlaying || !mounted) {
      return;
    }

    final index = _engine.board.tiles.indexWhere(
      (tile) => tile?.value == value,
    );
    if (index < 0) {
      _showChapterComplete();
      return;
    }

    setState(() {
      _completionAnimationPlaying = true;
      _completionAnimationIndex = index;
      _completionAnimationImagePath =
          _engine.board.tiles[index]!.creature.imagePath;
    });

    _completionAnimationController
      ..reset()
      ..forward();
  }

  Widget _buildCompletionAnimation() {
    final index = _completionAnimationIndex;
    final imagePath = _completionAnimationImagePath;

    if (!_completionAnimationPlaying ||
        index == null ||
        imagePath == null) {
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
            final startCenter = Offset(
              startX + tileSize / 2,
              startY + tileSize / 2,
            );
            final boardCenter = Offset(
              constraints.maxWidth / 2,
              constraints.maxHeight / 2,
            );

            return AnimatedBuilder(
              animation: _completionAnimationController,
              builder: (context, child) {
                final progress = Curves.easeInOutCubic.transform(
                  _completionAnimationController.value,
                );
                final center = Offset.lerp(startCenter, boardCenter, progress)!;
                final scale = 1 + progress * 3.0;

                return Transform.translate(
                  offset: center - boardCenter,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Evolution Notice
  // ============================================================

  void _showEvolutionNotice(int value) {
    if (!mounted) {
      return;
    }

    setState(() {
      _evolutionValue = value;
      _evolutionCreatureName = _creatureNameForValue(value);
    });
  }

  // ============================================================
  // Creature name
  // ============================================================

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
      if (creature.value == value) {
        return creature.name;
      }
    }

    return '';
  }

  // ============================================================
  // Restart
  // ============================================================

  bool _reset() {
    if (!mounted || _completionAnimationPlaying) {
      return false;
    }

    var restarted = false;

    setState(() {
      restarted = _engine.restart();

      if (!restarted) {
        return;
      }

      _evolutionValue = null;
      _evolutionCreatureName = null;

      _firstSwapIndex = null;
      _dragStart = null;
      _swipeHandled = false;
      _toolMode = null;
      _pressedToolMode = null;
    });

    if (!restarted) {
      return false;
    }

    _engine.startGameTimer();
    _startUiRefreshTimer();

    _focusNode.requestFocus();
    return true;
  }

  // ============================================================
  // Tools
  // ============================================================

  void _startTool(String mode) {
    if (!_engine.hasTools ||
        _engine.gameOver ||
        _engine.chapterComplete ||
        _gameOverDialogShowing ||
        _chapterCompleteShowing ||
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

    if (toolType == null) {
      return;
    }

    final toolState = _engine.toolManager.getTool(toolType);

    if (toolState == null) {
      return;
    }

    // Only open Shop when the tool has zero remaining uses.
    if (!toolState.canUse) {
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShopPage(initialTool: toolType),
        ),
      ).then((_) {
        if (!mounted) return;

        _engine.refreshToolProgress();
        setState(() {});
      });

      return;
    }

    // UNDO may have uses but cannot work before a previous move exists.
    // This must not open Shop.
    if (mode == 'rewind') {
      if (!_engine.canUseTimeRewind) {
        return;
      }

      if (_engine.useTimeRewind()) {
        setState(() {});
      }

      _focusNode.requestFocus();
      return;
    }

    // Other tools enter selection mode when they have available uses.
    setState(() {
      _toolMode = mode;
      _firstSwapIndex = null;
    });
  }
  void _selectToolTile(int index) {
    final mode = _toolMode;

    if (mode == null) {
      return;
    }

    final tile = _engine.board.tiles[index];

    final row = index ~/ 4;
    final column = index % 4;

    // ----------------------------------------------------------
    // Duplicate
    // ----------------------------------------------------------

    if (mode == 'duplicate') {
      if (_firstSwapIndex == null) {
        if (tile == null) {
          return;
        }

        setState(() {
          _firstSwapIndex = index;
        });

        return;
      }

      final first = _firstSwapIndex!;

      if (first == index || tile != null) {
        return;
      }

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

    if (tile == null) {
      return;
    }

    // ----------------------------------------------------------
    // Revive
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // Position Swap
    // ----------------------------------------------------------

    if (mode == 'swap') {
      if (_firstSwapIndex == null) {
        setState(() {
          _firstSwapIndex = index;
        });

        return;
      }

      final first = _firstSwapIndex!;

      if (first == index) {
        return;
      }

      final changed = _engine.usePositionSwap(
        first ~/ 4,
        first % 4,
        row,
        column,
      );

      if (changed) {
        setState(() {
          _toolMode = null;
          _firstSwapIndex = null;
        });

        _focusNode.requestFocus();
      }
    }
  }

  // ============================================================
  // Game Over
  // ============================================================

  Future<void> _showGameOver() async {
    if (_gameOverDialogShowing || !mounted) {
      return;
    }

    _gameOverDialogShowing = true;
    _engine.stopGameTimer();

    await AudioManager.instance.stopMusic();
    await AudioManager.instance.playSfx(GameSfx.gameOver);

    if (!mounted) {
      return;
    }

    final shouldRestart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text(
            'Score: ${_engine.score}\n'
            'Highest: ${_engine.highestValue}',
          ),
          actions: [
            TextButton(
              onPressed: () {
                unawaited(
                  AudioManager.instance.playSfx(GameSfx.buttonClick),
                );
                Navigator.of(context).pop(false);
              },
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () {
                unawaited(
                  AudioManager.instance.playSfx(GameSfx.buttonClick),
                );
                Navigator.of(context).pop(true);
              },
              child: const Text('Restart'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    _gameOverDialogShowing = false;

    if (shouldRestart == true) {
      if (_reset()) {
        unawaited(
          AudioManager.instance.playChapterMusic(_engine.chapter),
        );
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  // ============================================================
  // Background
  // ============================================================

  String _backgroundForHighest(int highestValue) {
    final backgrounds = switch (_engine.chapter) {
      GameChapter.ocean => _oceanBackgrounds,
      GameChapter.land => _landBackgrounds,
      GameChapter.sky => _skyBackgrounds,
      GameChapter.history => _historyBackgrounds,
      GameChapter.tech => _techBackgrounds,
      GameChapter.universe => _universeBackgrounds,
    };

    if (highestValue >= 1024) {
      return backgrounds[3];
    }

    if (highestValue >= 128) {
      return backgrounds[2];
    }

    if (highestValue >= 16) {
      return backgrounds[1];
    }

    return backgrounds[0];
  }

  // ============================================================
  // Chapter title
  // ============================================================

  String get _chapterTitle => switch (_engine.chapter) {
    GameChapter.ocean => 'Ocean Chapter',
    GameChapter.land => 'Land Chapter',
    GameChapter.sky => 'Sky Chapter',
    GameChapter.history => 'History Chapter',
    GameChapter.tech => 'Technology Chapter',
    GameChapter.universe => 'Universe Chapter',
  };

  // ============================================================
  // Debug complete
  // ============================================================

  void _debugCompleteChapter() {
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _completionAnimationPlaying) {
      return;
    }

    setState(() {
      _engine.debugCompleteChapter(_chapterNumber);
    });

    _showChapterComplete();
  }

  int get _chapterNumber => switch (_engine.chapter) {
    GameChapter.ocean => 1,
    GameChapter.land => 2,
    GameChapter.sky => 3,
    GameChapter.history => 4,
    GameChapter.tech => 5,
    GameChapter.universe => 6,
  };

  // ============================================================
  // Chapter Complete
  // ============================================================

  Future<void> _showChapterComplete() async {
    if (_chapterCompleteShowing || !mounted) {
      return;
    }

    _chapterCompleteShowing = true;
    _engine.stopGameTimer();

    final completedChapter = _engine.chapter;

    await AudioManager.instance.stopMusic();
    await AudioManager.instance.playSfxAndWait(GameSfx.chapterUnlock);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return _ChapterCompletePage(
            chapter: completedChapter,
            score: _engine.score,
            highestValue: _engine.highestValue,
            onContinue: () {
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    _chapterCompleteShowing = false;

    _completionAnimationPlaying = false;
    _completionAnimationIndex = null;
    _completionAnimationImagePath = null;

    switch (completedChapter) {
      case GameChapter.ocean:
        _startChapter(GameChapter.land, forceNewBoard: true);
        break;

      case GameChapter.land:
        _startChapter(GameChapter.sky, forceNewBoard: true);
        break;

      case GameChapter.sky:
        _startChapter(GameChapter.history, forceNewBoard: true);
        break;

      case GameChapter.history:
        _startChapter(GameChapter.tech, forceNewBoard: true);
        break;

      case GameChapter.tech:
        _startChapter(GameChapter.universe, forceNewBoard: true);
        break;

      case GameChapter.universe:
        _focusNode.requestFocus();

        break;
    }
  }

  // ============================================================
  // Start Chapter
  // ============================================================

  void _startChapter(GameChapter chapter, {bool forceNewBoard = false}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _engine = GameEngine(chapter: chapter, forceNewBoard: forceNewBoard);

      _toolMode = null;
      _firstSwapIndex = null;

      _dragStart = null;
      _swipeHandled = false;

      _evolutionValue = null;
      _evolutionCreatureName = null;
    });

    _engine.updateLifeFromRealTime();
    _engine.startGameTimer();
    _startUiRefreshTimer();

    AudioManager.instance.playChapterMusic(chapter);

    _focusNode.requestFocus();
  }

  // ============================================================
  // Tool label
  // ============================================================

  String _toolLabel(GameToolType type) {
    switch (type) {
      case GameToolType.revive:
        return 'REMOVE';

      case GameToolType.timeRewind:
        return 'UNDO';

      case GameToolType.positionSwap:
        return 'SWAP';

      case GameToolType.duplicate:
        return 'DUPLICATE';
    }
  }

  String _toolModeForType(GameToolType type) {
    switch (type) {
      case GameToolType.revive:
        return 'revive';

      case GameToolType.timeRewind:
        return 'rewind';

      case GameToolType.positionSwap:
        return 'swap';

      case GameToolType.duplicate:
        return 'duplicate';
    }
  }

  String _toolImagePath(String mode, {required bool pressed}) {
    return switch (mode) {
      'rewind' =>
        pressed
            ? 'assets/tools/tool_undo_pressed.png'
            : 'assets/tools/tool_undo.png',

      'swap' =>
        pressed
            ? 'assets/tools/tool_swap_pressed.png'
            : 'assets/tools/tool_swap.png',

      'revive' =>
        pressed
            ? 'assets/tools/tool_remove_pressed.png'
            : 'assets/tools/tool_remove.png',

      'duplicate' =>
        pressed
            ? 'assets/tools/tool_duplicate_pressed.png'
            : 'assets/tools/tool_duplicate.png',

      _ => '',
    };
  }

  Widget _buildToolButton(GameToolType type) {
    final mode = _toolModeForType(type);

    final matching = _engine.toolManager.tools.where(
      (state) => state.tool.type == type,
    );

    final state = matching.isEmpty ? null : matching.first;

    final unlocked = state != null;

    final enabled =
        unlocked &&
        state.canUse &&
        switch (type) {
          GameToolType.revive => _engine.canUseRevive,
          GameToolType.timeRewind => _engine.canUseTimeRewind,
          GameToolType.positionSwap => _engine.canUsePositionSwap,
          GameToolType.duplicate => _engine.canUseDuplicate,
        };

    final selected = _toolMode == mode;
    final pressed = _pressedToolMode == mode;

    final opacity = selected ? 0.45 : (unlocked ? 1.0 : 0.35);

    // ??踝???雓???頦????????????鞈?????????頩???????????
    final canOpenShop = unlocked && !state.canUse;
    final canTap = selected || enabled || canOpenShop;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTapDown: canTap
          ? (_) {
              setState(() {
                _pressedToolMode = mode;
              });

            }
          : null,

      onTapUp: canTap
          ? (_) {
              if (!mounted) {
                return;
              }

              setState(() {
                _pressedToolMode = null;
              });

              if (selected) {
                unawaited(AudioManager.instance.playSfx(GameSfx.buttonCancel));
                setState(() {
                  _toolMode = null;
                  _firstSwapIndex = null;
                  _pressedToolMode = null;
                });
                _focusNode.requestFocus();
              } else {
                unawaited(AudioManager.instance.playSfx(GameSfx.toolSelect));
                _startTool(mode);
              }
            }
          : null,

      onTapCancel: canTap
          ? () {
              if (!mounted) {
                return;
              }

              setState(() {
                _pressedToolMode = null;
              });
            }
          : null,

      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 76,
                    height: 72,
                    child: Image.asset(
                      _toolImagePath(mode, pressed: pressed),
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    selected ? 'CANCEL' : _toolLabel(type),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 1),

                  Text(
                    state == null ? '?' : '${state.usesRemaining}',
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),

              if (!unlocked)
                const Positioned(top: 4, child: Icon(Icons.lock, size: 25)),

              if (selected)
                const Positioned(
                  top: 2,
                  child: Text(
                    'CANCEL',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Evolution notice widget
  // ============================================================

  Widget _buildEvolutionNotice() {
    final value = _evolutionValue ?? _engine.highestEvolutionValue;
    final name = _evolutionCreatureName ?? _creatureNameForValue(value);

    if (name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.68),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // Main UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final background = _backgroundForHighest(_engine.highestValue);
    final l10n = AppLocalizations.of(context)!;
    final lifeRemaining = _engine.lifeRegenerationRemaining;
    final lifeCountdown = lifeRemaining == null
        ? ''
        : ' (${_formatDuration(lifeRemaining)})';

    return Scaffold(
      appBar: AppBar(
        title: Text(_chapterTitle),
        actions: [
          IconButton(
            onPressed: () {
              unawaited(AudioManager.instance.playSfx(GameSfx.buttonClick));
              _debugCompleteChapter();
            },
            tooltip: 'Test Chapter Complete',
            icon: const Icon(Icons.bug_report),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ------------------------------------------------
                      // Score
                      // ------------------------------------------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Score ${_engine.score}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Best ${_engine.bestScore}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${l10n.life} ${_engine.lives}$lifeCountdown',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${l10n.gameTime} ${_engine.formattedGameTime}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                onPressed: _completionAnimationPlaying
                                    ? null
                                    : () {
                                        unawaited(
                                          AudioManager.instance.playSfx(
                                            GameSfx.buttonClick,
                                          ),
                                        );
                                        _reset();
                                      },
                                tooltip: 'Restart',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: const Icon(Icons.refresh, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------------
                      // Highest
                      // ------------------------------------------------
                      Text(
                        _toolMode == null
                            ? 'Highest: ${_engine.highestValue} / ${_engine.targetValue}'
                            : 'Select a tile for '
                                  '${_toolMode == 'swap'
                                      ? 'Swap'
                                      : _toolMode == 'duplicate'
                                      ? 'Duplicate'
                                      : 'REMOVE'}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 10),

                      _buildEvolutionNotice(),

                      // ------------------------------------------------
                      // Board
                      // ------------------------------------------------
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(background, fit: BoxFit.cover),

                              Container(
                                color: Colors.black.withValues(alpha: 0.18),
                              ),

                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 6,
                                      mainAxisSpacing: 6,
                                    ),
                                itemCount: 16,
                                itemBuilder: (context, index) {
                                  final tile = _engine.board.tiles[index];
final selected = _firstSwapIndex == index;

                                  return GestureDetector(
                                    onTap: () => _selectToolTile(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: selected
                                            ? Border.all(
                                                width: 3,
                                                color: Colors.yellow,
                                              )
                                            : null,
                                        color: tile == null
                                            ? Colors.white.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.82,
                                              ),
                                      ),
                                      padding: EdgeInsets.all(
                                        _engine.chapter == GameChapter.universe
                                            ? 2
                                            : 6,
                                      ),
                                      child: tile == null
                                          ? const SizedBox.shrink()
                                          : Image.asset(
                                              tile.creature.imagePath,
                                              fit: BoxFit.contain,
                                            ),
                                    ),
                                  );
                                },
                              ),

                              _buildCompletionAnimation(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------------
                      // Tools - fixed single horizontal row
                      // ------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildToolButton(GameToolType.timeRewind),
                            ),
                            Expanded(
                              child: _buildToolButton(
                                GameToolType.positionSwap,
                              ),
                            ),
                            Expanded(
                              child: _buildToolButton(GameToolType.revive),
                            ),
                            Expanded(
                              child: _buildToolButton(GameToolType.duplicate),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// Chapter Complete Page
// ==================================================================

class _ChapterCompletePage extends StatelessWidget {
  const _ChapterCompletePage({
    required this.chapter,
    required this.score,
    required this.highestValue,
    required this.onContinue,
  });

  final GameChapter chapter;
  final int score;
  final int highestValue;
  final VoidCallback onContinue;

  String get _background => switch (chapter) {
    GameChapter.ocean =>
      'assets/backgrounds/chapter_01_ocean/ocean_chapter_complete.jpg',
    GameChapter.land =>
      'assets/backgrounds/chapter_02_land/land_chapter_complete.jpg',
    GameChapter.sky =>
      'assets/backgrounds/chapter_03_sky/sky_chapter_complete.jpg',
    GameChapter.history =>
      'assets/backgrounds/chapter_04_history/chapter_04_history_complete.png',
    GameChapter.tech => 'assets/backgrounds/chapter_05_tech/tech_complete.png',
    GameChapter.universe =>
      'assets/backgrounds/chapter_06_universe/universe_chapter_complete.jpg',
  };

  String get _title => switch (chapter) {
    GameChapter.ocean => 'Ocean Restored',
    GameChapter.land => 'Land Restored',
    GameChapter.sky => 'Sky Restored',
    GameChapter.history => 'History Restored',
    GameChapter.tech => 'Technology Restored',
    GameChapter.universe => 'Universe Restored',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(_background, fit: BoxFit.cover),

          Container(color: Colors.black.withValues(alpha: 0.18)),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),

                  Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Score $score  繚  Highest $highestValue',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          unawaited(
                            AudioManager.instance.playSfx(GameSfx.buttonClick),
                          );
                          onContinue();
                        },
                        child: const Text('Continue'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


















