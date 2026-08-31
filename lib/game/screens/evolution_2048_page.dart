import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';
import '../services/game_engine.dart';

class Evolution2048Page extends StatefulWidget {
  const Evolution2048Page({super.key});

  @override
  State<Evolution2048Page> createState() => _Evolution2048PageState();
}

class _Evolution2048PageState extends State<Evolution2048Page> {
  GameEngine _engine = GameEngine(chapter: GameChapter.ocean);
  final FocusNode _focusNode = FocusNode();

  Offset? _dragStart;
  bool _swipeHandled = false;
  bool _gameOverDialogShowing = false;
  bool _chapterCompleteShowing = false;

  String? _toolMode;
  int? _firstSwapIndex;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
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
    if (direction == null) return KeyEventResult.ignored;
    _move(direction);
    return KeyEventResult.handled;
  }

  void _handleDragStart(DragStartDetails details) {
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
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
    if (_gameOverDialogShowing ||
        _chapterCompleteShowing ||
        _toolMode != null) {
      return;
    }

    var changed = false;

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
    }

    if (!changed) {
      return;
    }

    if (mounted) {
      setState(() {});
    }

    if (_engine.chapterComplete) {
      _showChapterComplete();
    } else if (_engine.gameOver) {
      _showGameOver();
    }
  }

  void _reset() {
    if (_gameOverDialogShowing || _chapterCompleteShowing) return;
    setState(() {
      _engine = GameEngine(chapter: _engine.chapter);
      _toolMode = null;
      _firstSwapIndex = null;
      _dragStart = null;
      _swipeHandled = false;
    });
    _focusNode.requestFocus();
  }

  void _startTool(String mode) {
    if (!_engine.hasTools ||
        _gameOverDialogShowing ||
        _chapterCompleteShowing) {
      return;
    }
    final canUse = switch (mode) {
      'revive' => _engine.canUseRevive,
      'rewind' => _engine.canUseTimeRewind,
      'swap' => _engine.canUsePositionSwap,
      'duplicate' => _engine.canUseDuplicate,
      _ => false,
    };
    if (!canUse) return;

    if (mode == 'rewind') {
      if (_engine.useTimeRewind()) setState(() {});
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _toolMode = mode;
      _firstSwapIndex = null;
    });
  }

  void _cancelTool() {
    if (_toolMode == null) return;
    setState(() {
      _toolMode = null;
      _firstSwapIndex = null;
    });
    _focusNode.requestFocus();
  }

  void _selectToolTile(int index) {
    final mode = _toolMode;
    if (mode == null) return;
    final tile = _engine.board.tiles[index];
    if (tile == null) return;

    final row = index ~/ 4;
    final column = index % 4;

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

    if (mode == 'duplicate') {
      if (_engine.useDuplicate(row, column)) {
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

  Future<void> _showGameOver() async {
    if (_gameOverDialogShowing || !mounted) return;
    _gameOverDialogShowing = true;
    final shouldRestart = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(
          'Score: ${_engine.score}\nHighest: ${_engine.highestValue}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _gameOverDialogShowing = false;
    if (shouldRestart == true) _reset();
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
    if (highestValue >= 1024) return backgrounds[3];
    if (highestValue >= 128) return backgrounds[2];
    if (highestValue >= 16) return backgrounds[1];
    return backgrounds[0];
  }

  String get _chapterTitle => switch (_engine.chapter) {
    GameChapter.ocean => 'Ocean Chapter',
    GameChapter.land => 'Land Chapter',
    GameChapter.sky => 'Sky Chapter',
    GameChapter.history => 'History Chapter',
    GameChapter.tech => 'Technology Chapter',
    GameChapter.universe => 'Universe Chapter',
  };

  void _debugCompleteChapter() {
    if (_gameOverDialogShowing || _chapterCompleteShowing) return;
    setState(() => _engine.debugCompleteChapter(_chapterNumber));
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

  Future<void> _showChapterComplete() async {
    if (_chapterCompleteShowing || !mounted) return;
    _chapterCompleteShowing = true;
    final completedChapter = _engine.chapter;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ChapterCompletePage(
          chapter: completedChapter,
          score: _engine.score,
          highestValue: _engine.highestValue,
          onContinue: () => Navigator.of(context).pop(),
        ),
      ),
    );

    if (!mounted) return;
    _chapterCompleteShowing = false;

    switch (completedChapter) {
      case GameChapter.ocean:
        _startChapter(GameChapter.land);
        break;
      case GameChapter.land:
        _startChapter(GameChapter.sky);
        break;
      case GameChapter.sky:
        _startChapter(GameChapter.history);
        break;
      case GameChapter.history:
        _startChapter(GameChapter.tech);
        break;
      case GameChapter.tech:
        _startChapter(GameChapter.universe);
        break;
      case GameChapter.universe:
        _focusNode.requestFocus();
        break;
    }
  }

  void _startChapter(GameChapter chapter) {
    if (!mounted) return;
    setState(() {
      _engine = GameEngine(chapter: chapter);
      _toolMode = null;
      _firstSwapIndex = null;
      _dragStart = null;
      _swipeHandled = false;
    });
    _focusNode.requestFocus();
  }

  String _toolLabel(GameToolType type) {
    switch (type) {
      case GameToolType.revive:
        return 'Revive';
      case GameToolType.timeRewind:
        return 'Rewind';
      case GameToolType.positionSwap:
        return 'Swap';
      case GameToolType.duplicate:
        return 'Duplicate';
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = _backgroundForHighest(_engine.highestValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chapterTitle),
        actions: [
          IconButton(
            onPressed: _reset,
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _debugCompleteChapter,
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
                      Text(
                        _toolMode == null
                            ? 'Highest: ${_engine.highestValue} / ${_engine.targetValue}'
                            : 'Select a tile for ${_toolMode == 'swap'
                                  ? 'Swap'
                                  : _toolMode == 'duplicate'
                                  ? 'Duplicate'
                                  : 'Revive'}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_toolMode != null)
                        TextButton(
                          onPressed: _cancelTool,
                          child: const Text('Cancel'),
                        )
                      else if (_engine.hasTools)
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: _engine.toolManager.tools.map((state) {
                            final type = state.tool.type;
                            final enabled =
                                state.canUse &&
                                switch (type) {
                                  GameToolType.revive => true,
                                  GameToolType.timeRewind =>
                                    _engine.canUseTimeRewind,
                                  GameToolType.positionSwap =>
                                    _engine.canUsePositionSwap,
                                  GameToolType.duplicate =>
                                    _engine.canUseDuplicate,
                                };
                            final mode = switch (type) {
                              GameToolType.revive => 'revive',
                              GameToolType.timeRewind => 'rewind',
                              GameToolType.positionSwap => 'swap',
                              GameToolType.duplicate => 'duplicate',
                            };
                            return OutlinedButton.icon(
                              onPressed: enabled
                                  ? () => _startTool(mode)
                                  : null,
                              icon: const Icon(Icons.build),
                              label: Text(
                                '${_toolLabel(type)} (${state.usesRemaining})',
                              ),
                            );
                          }).toList(),
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
                    'Score $score  •  Highest $highestValue',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onContinue,
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
