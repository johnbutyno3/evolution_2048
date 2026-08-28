import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _Chapter { ocean, land, sky, history, tech }
enum _Tool { revive, rewind, swap, duplicate }

class Evolution2048ChaptersPage extends StatefulWidget {
  const Evolution2048ChaptersPage({super.key});

  @override
  State<Evolution2048ChaptersPage> createState() =>
      _Evolution2048ChaptersPageState();
}

class _Evolution2048ChaptersPageState extends State<Evolution2048ChaptersPage> {
  final FocusNode _focus = FocusNode();
  final Random _random = Random();

  _Chapter _chapter = _Chapter.ocean;
  List<int?> _tiles = List<int?>.filled(16, null);
  List<int?>? _previous;
  int? _swapFirst;
  int _score = 0;
  int _best = 0;
  bool _gameOver = false;
  bool _complete = false;
  _Tool? _selecting;
  final Set<_Tool> _used = <_Tool>{};
  Offset? _dragStart;
  bool _handledSwipe = false;

  static const _techCreatures = <int, String>{
    2: 'assets/creatures/chapter_05_modern_world/modern_02_watch.png',
    4: 'assets/creatures/chapter_05_modern_world/modern_04_camera.png',
    8: 'assets/creatures/chapter_05_modern_world/modern_08_radio.png',
    16: 'assets/creatures/chapter_05_modern_world/modern_16_television.png',
    32: 'assets/creatures/chapter_05_modern_world/modern_32_washing_machine.png',
    64: 'assets/creatures/chapter_05_modern_world/modern_64_refrigerator.png',
    128: 'assets/creatures/chapter_05_modern_world/modern_128_microwave.png',
    256: 'assets/creatures/chapter_05_modern_world/modern_256_game_controller.png',
    512: 'assets/creatures/chapter_05_modern_world/modern_512_laptop.png',
    1024: 'assets/creatures/chapter_05_modern_world/modern_1024_smartphone.png',
    2048: 'assets/creatures/chapter_05_modern_world/modern_2048_tablet.png',
    4096: 'assets/creatures/chapter_05_modern_world/modern_4096_drone.png',
    8192: 'assets/creatures/chapter_05_modern_world/modern_8192_vr_headset.png',
    16384: 'assets/creatures/chapter_05_modern_world/modern_16384_robot.png',
    32768: 'assets/creatures/chapter_05_modern_world/modern_32768_ai_core.png',
    65536: 'assets/creatures/chapter_05_modern_world/modern_65536_future_device.png',
  };

  static const _backgrounds = <_Chapter, List<String>>{
    _Chapter.ocean: [
      'assets/backgrounds/chapter_01_ocean/ocean_background_01_primordial.jpg',
      'assets/backgrounds/chapter_01_ocean/ocean_background_02_shallow_sea.jpg',
      'assets/backgrounds/chapter_01_ocean/ocean_background_03_coral_reef.jpg',
      'assets/backgrounds/chapter_01_ocean/ocean_background_04_deep_ocean.jpg',
    ],
    _Chapter.land: [
      'assets/backgrounds/chapter_02_land/land_background_01_primordial.jpg',
      'assets/backgrounds/chapter_02_land/land_background_02_forest.jpg',
      'assets/backgrounds/chapter_02_land/land_background_03_jungle.jpg',
      'assets/backgrounds/chapter_02_land/land_background_04_ancient_land.jpg',
    ],
    _Chapter.sky: [
      'assets/backgrounds/chapter_03_sky/sky_background_01_low_altitude.jpg',
      'assets/backgrounds/chapter_03_sky/sky_background_02_mid_altitude.jpg',
      'assets/backgrounds/chapter_03_sky/sky_background_03_high_altitude.jpg',
      'assets/backgrounds/chapter_03_sky/sky_background_04_space.jpg',
    ],
    _Chapter.history: [
      'assets/backgrounds/chapter_04_history/chapter_04_history_bg_01.png',
      'assets/backgrounds/chapter_04_history/chapter_04_history_bg_02.png',
      'assets/backgrounds/chapter_04_history/chapter_04_history_bg_03.png',
      'assets/backgrounds/chapter_04_history/chapter_04_history_bg_04.png',
    ],
    _Chapter.tech: [
      'assets/backgrounds/chapter_05_tech/tech_01_electronic_age.png',
      'assets/backgrounds/chapter_05_tech/tech_02_ai_robot.png',
      'assets/backgrounds/chapter_05_tech/tech_03_future_city.png',
      'assets/backgrounds/chapter_05_tech/tech_04_space_civilization.png',
    ],
  };

  static const _completeBackgrounds = <_Chapter, String>{
    _Chapter.ocean:
        'assets/backgrounds/chapter_01_ocean/ocean_chapter_complete.jpg',
    _Chapter.land:
        'assets/backgrounds/chapter_02_land/land_chapter_complete.jpg',
    _Chapter.sky:
        'assets/backgrounds/chapter_03_sky/sky_chapter_complete.jpg',
    _Chapter.history:
        'assets/backgrounds/chapter_04_history/chapter_04_history_complete.png',
    _Chapter.tech: 'assets/backgrounds/chapter_05_tech/tech_complete.png',
  };

  @override
  void initState() {
    super.initState();
    _resetBoard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  int get _target => const {
        _Chapter.ocean: 4096,
        _Chapter.land: 8192,
        _Chapter.sky: 16384,
        _Chapter.history: 32768,
        _Chapter.tech: 65536,
      }[_chapter]!;

  String get _title => const {
        _Chapter.ocean: 'Ocean Chapter',
        _Chapter.land: 'Land Chapter',
        _Chapter.sky: 'Sky Chapter',
        _Chapter.history: 'History Chapter',
        _Chapter.tech: 'Tech Chapter',
      }[_chapter]!;

  List<_Tool> get _tools => switch (_chapter) {
        _Chapter.ocean => const [_Tool.revive],
        _Chapter.land => const [_Tool.revive],
        _Chapter.sky => const [_Tool.revive, _Tool.rewind],
        _Chapter.history => const [_Tool.revive, _Tool.rewind, _Tool.swap],
        _Chapter.tech =>
          const [_Tool.revive, _Tool.rewind, _Tool.swap, _Tool.duplicate],
      };

  void _resetBoard() {
    _tiles = List<int?>.filled(16, null);
    _previous = null;
    _swapFirst = null;
    _score = 0;
    _gameOver = false;
    _complete = false;
    _selecting = null;
    _used.clear();
    _spawn();
    _spawn();
  }

  void _spawn() {
    final empty = <int>[];
    for (var i = 0; i < 16; i++) {
      if (_tiles[i] == null) {
        empty.add(i);
      }
    }
    if (empty.isEmpty) {
      return;
    }
    final index = empty[_random.nextInt(empty.length)];
    _tiles[index] = _random.nextDouble() < .9 ? 2 : 4;
  }

  bool _move(String direction) {
    if (_gameOver || _complete || _selecting != null) {
      return false;
    }

    _previous = List<int?>.from(_tiles);
    final next = List<int?>.filled(16, null);
    var changed = false;
    var gained = 0;

    for (var line = 0; line < 4; line++) {
      final values = <int>[];
      for (var p = 0; p < 4; p++) {
        final r = direction == 'left' || direction == 'right' ? line : p;
        final c = direction == 'left' || direction == 'right' ? p : line;
        final rr = direction == 'down' ? 3 - r : r;
        final cc = direction == 'right' ? 3 - c : c;
        final value = _tiles[rr * 4 + cc];
        if (value != null) {
          values.add(value);
        }
      }

      final merged = <int>[];
      for (var i = 0; i < values.length; i++) {
        if (i + 1 < values.length && values[i] == values[i + 1]) {
          final v = values[i] * 2;
          merged.add(v);
          gained += v;
          i++;
        } else {
          merged.add(values[i]);
        }
      }

      for (var p = 0; p < 4; p++) {
        final value = p < merged.length ? merged[p] : null;
        final r = direction == 'left' || direction == 'right' ? line : p;
        final c = direction == 'left' || direction == 'right' ? p : line;
        final rr = direction == 'down' ? 3 - r : r;
        final cc = direction == 'right' ? 3 - c : c;
        next[rr * 4 + cc] = value;
      }
    }

    for (var i = 0; i < 16; i++) {
      if (next[i] != _tiles[i]) {
        changed = true;
        break;
      }
    }

    if (!changed) {
      _previous = null;
      _gameOver = _isGameOver();
      if (_gameOver) {
        setState(() {});
        _showGameOver();
      }
      return false;
    }

    _tiles = next;
    _score += gained;
    if (_score > _best) {
      _best = _score;
    }

    _complete = _tiles.whereType<int>().any((v) => v >= _target);

    if (!_complete) {
      _spawn();
      _gameOver = _isGameOver();
    }

    setState(() {});

    if (_complete) {
      _showComplete();
    } else if (_gameOver) {
      _showGameOver();
    }

    return true;
  }

  bool _isGameOver() {
    if (_tiles.any((v) => v == null)) {
      return false;
    }

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final v = _tiles[r * 4 + c]!;
        if (c < 3 && _tiles[r * 4 + c + 1] == v) {
          return false;
        }
        if (r < 3 && _tiles[(r + 1) * 4 + c] == v) {
          return false;
        }
      }
    }

    return true;
  }

  void _showGameOver() {
    if (!mounted || !_gameOver || _complete) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('GAME OVER'),
        content: Text('No more moves.\n\nSCORE  $_score'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('USE TOOL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(_resetBoard);
              _focus.requestFocus();
            },
            child: const Text('RESTART'),
          ),
        ],
      ),
    );
  }

  void _useTool(_Tool tool) {
    if (_used.contains(tool) || !_tools.contains(tool) || _complete) {
      return;
    }

    if (tool == _Tool.rewind) {
      if (_previous == null) {
        return;
      }
      _tiles = List<int?>.from(_previous!);
      _previous = null;
      _swapFirst = null;
      _used.add(tool);
      _selecting = null;
      _gameOver = false;
      setState(() {});
      return;
    }

    _swapFirst = null;
    setState(() => _selecting = tool);
  }

  void _selectTile(int index) {
    final tool = _selecting;
    if (tool == null || _tiles[index] == null) {
      return;
    }

    if (tool == _Tool.revive) {
      _tiles[index] = null;
      _finishToolUse(tool);
      return;
    }

    if (tool == _Tool.duplicate) {
      final value = _tiles[index]!;
      if (value >= 512) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate is limited to tiles up to 256.')),
        );
        return;
      }
      final empty = _tiles.indexWhere((v) => v == null);
      if (empty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No empty position available.')),
        );
        return;
      }
      _tiles[empty] = value;
      _finishToolUse(tool);
      return;
    }

    if (tool == _Tool.swap) {
      if (_swapFirst == null) {
        _swapFirst = index;
        setState(() {});
        return;
      }

      if (_swapFirst == index) {
        _swapFirst = null;
        setState(() {});
        return;
      }

      final first = _swapFirst!;
      final temp = _tiles[first];
      _tiles[first] = _tiles[index];
      _tiles[index] = temp;
      _finishToolUse(tool);
    }
  }

  void _finishToolUse(_Tool tool) {
    _used.add(tool);
    _selecting = null;
    _swapFirst = null;
    _gameOver = false;
    setState(() {});
  }

  void _showComplete() {
    if (!mounted) {
      return;
    }

    final chapter = _chapter;
    Navigator.of(context)
        .push(
          PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, animation, __) => _CompletePage(
              chapter: chapter,
              background: _completeBackgrounds[chapter]!,
              score: _score,
              onContinue: () => Navigator.of(context).pop(),
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        )
        .then((_) {
          if (!mounted) {
            return;
          }
          if (chapter == _Chapter.tech) {
            _focus.requestFocus();
            return;
          }
          setState(() {
            _chapter = _Chapter.values[chapter.index + 1];
            _resetBoard();
          });
          _focus.requestFocus();
        });
  }

  void _debugComplete() {
    setState(() {
      _tiles = List<int?>.filled(16, null)..[0] = _target;
      _complete = true;
    });
    _showComplete();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final d = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => 'up',
      LogicalKeyboardKey.arrowDown => 'down',
      LogicalKeyboardKey.arrowLeft => 'left',
      LogicalKeyboardKey.arrowRight => 'right',
      _ => null,
    };

    if (d != null) {
      _move(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highest = _tiles.whereType<int>().fold<int>(0, max);
    final bg = _backgrounds[_chapter]![_backgroundIndex(highest)];

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: _resetBoard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _debugComplete,
            icon: const Icon(Icons.bug_report),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _focus,
          onKeyEvent: (_, event) {
            _handleKey(event);
            return KeyEventResult.handled;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Stat('SCORE', _score)),
                        const SizedBox(width: 8),
                        Expanded(child: _Stat('BEST', _best)),
                        const SizedBox(width: 8),
                        Expanded(child: _Stat('HIGHEST', highest)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_tools.isNotEmpty)
                      _Tools(
                        tools: _tools,
                        used: _used,
                        selecting: _selecting,
                        onTool: _useTool,
                        onCancel: () => setState(() {
                          _selecting = null;
                          _swapFirst = null;
                        }),
                      ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onPanStart: (d) => _dragStart = d.localPosition,
                      onPanUpdate: (d) {
                        if (_dragStart == null || _handledSwipe) {
                          return;
                        }
                        final delta = d.localPosition - _dragStart!;
                        if (delta.distance < 30) {
                          return;
                        }
                        _handledSwipe = true;
                        _move(
                          delta.dx.abs() > delta.dy.abs()
                              ? (delta.dx < 0 ? 'left' : 'right')
                              : (delta.dy < 0 ? 'up' : 'down'),
                        );
                      },
                      onPanEnd: (_) {
                        _dragStart = null;
                        _handledSwipe = false;
                      },
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                bg,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.blueGrey),
                              ),
                              Container(
                                color: Colors.black.withValues(alpha: .08),
                              ),
                              GridView.builder(
                                padding: const EdgeInsets.all(8),
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 6,
                                  mainAxisSpacing: 6,
                                ),
                                itemCount: 16,
                                itemBuilder: (_, index) => GestureDetector(
                                  onTap: _selecting == null
                                      ? null
                                      : () => _selectTile(index),
                                  child: _Tile(
                                    value: _tiles[index],
                                    image: _imageFor(_tiles[index]),
                                    highlighted: _selecting != null &&
                                        _tiles[index] != null,
                                    selected: _swapFirst == index,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selecting == null
                          ? 'Use arrow keys or swipe to move.'
                          : _selecting == _Tool.swap
                              ? (_swapFirst == null
                                  ? 'Tap the first tile to swap.'
                                  : 'Tap the second tile to swap.')
                              : 'Tap a tile for the selected tool.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _backgroundIndex(int value) => value >= 1024
      ? 3
      : value >= 128
          ? 2
          : value >= 16
              ? 1
              : 0;

  String? _imageFor(int? value) {
    if (value == null) {
      return null;
    }
    if (_chapter == _Chapter.tech) {
      return _techCreatures[value];
    }

    switch (_chapter) {
      case _Chapter.ocean:
        const images = {
          2: 'assets/creatures/chapter_01_ocean/creature_02.png',
          4: 'assets/creatures/chapter_01_ocean/creature_04.png',
          8: 'assets/creatures/chapter_01_ocean/creature_08.png',
          16: 'assets/creatures/chapter_01_ocean/creature_16.png',
          32: 'assets/creatures/chapter_01_ocean/creature_32.png',
          64: 'assets/creatures/chapter_01_ocean/creature_64.png',
          128: 'assets/creatures/chapter_01_ocean/creature_128.png',
          256: 'assets/creatures/chapter_01_ocean/creature_256.png',
          512: 'assets/creatures/chapter_01_ocean/creature_512.png',
          1024: 'assets/creatures/chapter_01_ocean/creature_1024.png',
          2048: 'assets/creatures/chapter_01_ocean/creature_2048.png',
          4096: 'assets/creatures/chapter_01_ocean/future_seabed_human.png',
        };
        return images[value];
      case _Chapter.land:
        const images = {
          2: 'assets/creatures/chapter_02_land/creature_02.png',
          4: 'assets/creatures/chapter_02_land/creature_04.png',
          8: 'assets/creatures/chapter_02_land/creature_08.png',
          16: 'assets/creatures/chapter_02_land/creature_16.png',
          32: 'assets/creatures/chapter_02_land/creature_32.png',
          64: 'assets/creatures/chapter_02_land/creature_64.png',
          128: 'assets/creatures/chapter_02_land/creature_128.png',
          256: 'assets/creatures/chapter_02_land/creature_256.png',
          512: 'assets/creatures/chapter_02_land/creature_512.png',
          1024: 'assets/creatures/chapter_02_land/creature_1024.png',
          2048: 'assets/creatures/chapter_02_land/creature_2048.png',
          4096: 'assets/creatures/chapter_02_land/creature_4096.png',
          8192: 'assets/creatures/chapter_02_land/creature_8192.png',
        };
        return images[value];
      case _Chapter.sky:
        const images = {
          2: 'assets/creatures/chapter_03_sky/creature_02.png',
          4: 'assets/creatures/chapter_03_sky/creature_04.png',
          8: 'assets/creatures/chapter_03_sky/creature_08.png',
          16: 'assets/creatures/chapter_03_sky/creature_16.png',
          32: 'assets/creatures/chapter_03_sky/creature_32.png',
          64: 'assets/creatures/chapter_03_sky/creature_64.png',
          128: 'assets/creatures/chapter_03_sky/creature_128.png',
          256: 'assets/creatures/chapter_03_sky/creature_256.png',
          512: 'assets/creatures/chapter_03_sky/creature_512.png',
          1024: 'assets/creatures/chapter_03_sky/creature_1024.png',
          2048: 'assets/creatures/chapter_03_sky/creature_2048.png',
          4096: 'assets/creatures/chapter_03_sky/creature_4096.png',
          8192: 'assets/creatures/chapter_03_sky/creature_8192.png',
          16384: 'assets/creatures/chapter_03_sky/creature_16384.png',
        };
        return images[value];
      case _Chapter.history:
        const images = {
          2: 'assets/creatures/chapter_04_history/history_02_fire.png',
          4: 'assets/creatures/chapter_04_history/history_04_civilization.png',
          8: 'assets/creatures/chapter_04_history/history_08_egypt.png',
          16: 'assets/creatures/chapter_04_history/history_16_rome.png',
          32: 'assets/creatures/chapter_04_history/history_32_tang.png',
          64: 'assets/creatures/chapter_04_history/history_64_mongol.png',
          128: 'assets/creatures/chapter_04_history/history_128_exploration.png',
          256: 'assets/creatures/chapter_04_history/history_256_independence.png',
          512: 'assets/creatures/chapter_04_history/history_512_industrial.png',
          1024: 'assets/creatures/chapter_04_history/history_1024_communication.png',
          2048: 'assets/creatures/chapter_04_history/history_2048_automobile.png',
          4096: 'assets/creatures/chapter_04_history/history_4096_flight.png',
          8192: 'assets/creatures/chapter_04_history/history_8192_world_war.png',
          16384: 'assets/creatures/chapter_04_history/history_16384_moon.png',
          32768: 'assets/creatures/chapter_04_history/history_32768_internet.png',
        };
        return images[value];
      case _Chapter.tech:
        return _techCreatures[value];
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.image,
    required this.highlighted,
    required this.selected,
  });

  final int? value;
  final String? image;
  final bool highlighted;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: selected
              ? Colors.orange.withValues(alpha: .65)
              : highlighted
                  ? Colors.amber.withValues(alpha: .5)
                  : Colors.white.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: Colors.deepOrange, width: 4)
              : highlighted
                  ? Border.all(color: Colors.amber, width: 3)
                  : null,
        ),
        child: value == null || image == null
            ? null
            : Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Image.asset(image!, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 3,
                    left: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      color: Colors.black45,
                      child: Text(
                        '$value',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.tools,
    required this.used,
    required this.selecting,
    required this.onTool,
    required this.onCancel,
  });

  final List<_Tool> tools;
  final Set<_Tool> used;
  final _Tool? selecting;
  final ValueChanged<_Tool> onTool;
  final VoidCallback onCancel;

  String _name(_Tool tool) => switch (tool) {
        _Tool.revive => 'REVIVE',
        _Tool.rewind => 'REWIND',
        _Tool.swap => 'POSITION SWAP',
        _Tool.duplicate => 'DUPLICATE',
      };

  IconData _icon(_Tool tool) => switch (tool) {
        _Tool.revive => Icons.auto_fix_high,
        _Tool.rewind => Icons.history,
        _Tool.swap => Icons.swap_horiz,
        _Tool.duplicate => Icons.copy,
      };

  @override
  Widget build(BuildContext context) => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.6,
        children: [
          for (final tool in tools)
            FilledButton.icon(
              onPressed: used.contains(tool)
                  ? null
                  : selecting == tool
                      ? onCancel
                      : () => onTool(tool),
              icon: Icon(_icon(tool)),
              label: Text(
                used.contains(tool)
                    ? '${_name(tool)} USED'
                    : selecting == tool
                        ? 'CANCEL'
                        : '${_name(tool)} 1 USE',
              ),
            ),
        ],
      );
}

class _CompletePage extends StatelessWidget {
  const _CompletePage({
    required this.chapter,
    required this.background,
    required this.score,
    required this.onContinue,
  });

  final _Chapter chapter;
  final String background;
  final int score;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(background, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: .32)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CHAPTER ${chapter.index + 1} COMPLETE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SCORE  $score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onContinue,
                    child: Text(
                      chapter == _Chapter.tech ? 'FINISH' : 'CONTINUE',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
