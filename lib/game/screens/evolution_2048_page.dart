import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_tile.dart';
import '../services/game_engine.dart';

class Evolution2048Page extends StatefulWidget {
  const Evolution2048Page({super.key});

  @override
  State<Evolution2048Page> createState() => _Evolution2048PageState();
}

class _Evolution2048PageState extends State<Evolution2048Page> {
  final _engine = GameEngine();
  final FocusNode _focusNode = FocusNode();
  Offset? _dragStart;
  bool _swipeHandled = false;
  bool _shown2048Milestone = false;
  bool _shown4096Milestone = false;
  bool _is4096Challenge = false;
  bool _isDialogOpen = false;

  static const double _swipeThreshold = 30;

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
    if (_isDialogOpen || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
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
    if (_isDialogOpen) return;
    _dragStart = details.localPosition;
    _swipeHandled = false;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDialogOpen || _swipeHandled || _dragStart == null) return;

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
    if (_isDialogOpen) return;

    final changed = switch (direction) {
      'up' => _engine.moveUp(),
      'down' => _engine.moveDown(),
      'left' => _engine.moveLeft(),
      'right' => _engine.moveRight(),
      _ => false,
    };

    if (changed && mounted) setState(() {});

    if (_engine.hasReached4096 && !_shown4096Milestone) {
      _shown4096Milestone = true;
      _showMilestone('4096', '海底人類');
    } else if (_engine.hasReached2048 && !_shown2048Milestone) {
      _shown2048Milestone = true;
      _show2048Unlock();
    } else if (_engine.gameOver) {
      _showGameOver();
    }
  }

  void _reset() {
    setState(() {
      _engine.reset();
      _shown2048Milestone = false;
      _shown4096Milestone = false;
      _is4096Challenge = false;
      _isDialogOpen = false;
      _dragStart = null;
      _swipeHandled = false;
    });
    _focusNode.requestFocus();
  }

  Future<void> _show2048Unlock() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isDialogOpen = true;
      final enterChallenge = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('2048 · 藍鯨'),
          content: const Text(
            'Chapter 1 普通階段完成。\n\n'
            '下一章已解鎖。\n'
            'Chapter 1 的 4096 終極挑戰也已解鎖。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('進入 4096 挑戰'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍後'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _isDialogOpen = false;
      if (enterChallenge == true) {
        setState(() => _is4096Challenge = true);
      }
      _focusNode.requestFocus();
    });
  }

  Future<void> _showMilestone(String value, String name) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(value),
          content: Text('$name 已誕生。\n\nChapter 1 完整通關。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
          ],
        ),
      );
      if (mounted) {
        _isDialogOpen = false;
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _showGameOver() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _isDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('本局結束'),
          content: const Text('棋盤已無法繼續合成。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reset();
              },
              child: const Text('重新開始'),
            ),
          ],
        ),
      );
      if (mounted) _isDialogOpen = false;
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final highestValue = _engine.board.tiles.whereType<GameTile>().fold<int>(
          0,
          (highest, tile) => tile.value > highest ? tile.value : highest,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _is4096Challenge
              ? 'Chapter 1 · 4096 終極挑戰'
              : 'Chapter 1 · Ocean',
        ),
        actions: [
          IconButton(
            onPressed: _reset,
            tooltip: '重新開始',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: _handleKey,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _is4096Challenge
                        ? '4096 終極挑戰 · 禁止工具'
                        : 'Chapter 1 · Ocean',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '最高分：$highestValue',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _handleDragStart,
                    onPanUpdate: _handleDragUpdate,
                    onPanEnd: _handleDragEnd,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        primary: false,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: 16,
                        itemBuilder: (context, index) {
                          return _TileView(tile: _engine.board.tiles[index]);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('手機：手指滑動｜電腦測試：方向鍵 ↑ ↓ ← →'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final GameTile? tile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: tile == null ? Colors.black12 : Colors.green.shade100,
      ),
      alignment: Alignment.center,
      child: tile == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${tile!.value}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(tile!.creature.name),
              ],
            ),
    );
  }
}
