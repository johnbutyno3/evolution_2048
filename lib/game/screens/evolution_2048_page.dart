import 'package:flutter/material.dart';

import '../models/game_tile.dart';
import '../services/game_engine.dart';

class Evolution2048Page extends StatefulWidget {
  const Evolution2048Page({super.key});

  @override
  State<Evolution2048Page> createState() => _Evolution2048PageState();
}

class _Evolution2048PageState extends State<Evolution2048Page> {
  final _engine = GameEngine();
  bool _shown2048Milestone = false;
  bool _shown4096Milestone = false;
  bool _is4096Challenge = false;

  void _move(String direction) {
    var changed = false;
    switch (direction) {
      case 'up':
        changed = _engine.moveUp();
      case 'down':
        changed = _engine.moveDown();
      case 'left':
        changed = _engine.moveLeft();
      case 'right':
        changed = _engine.moveRight();
    }

    if (changed) setState(() {});

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

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < 50) return;
    _move(velocity < 0 ? 'up' : 'down');
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < 50) return;
    _move(velocity < 0 ? 'left' : 'right');
  }

  void _reset() {
    setState(() {
      _engine.reset();
      _shown2048Milestone = false;
      _shown4096Milestone = false;
      _is4096Challenge = false;
    });
  }

  void _show2048Unlock() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
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
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _is4096Challenge = true);
              },
              child: const Text('進入 4096 挑戰'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('稍後'),
            ),
          ],
        ),
      );
    });
  }

  void _showMilestone(String value, String name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
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
    });
  }

  void _showGameOver() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _is4096Challenge ? '4096 終極挑戰 · 禁止工具' : 'Chapter 1 · Ocean',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '2048：${_engine.hasReached2048 ? '✓' : '未達成'}   '
                  '4096：${_engine.hasReached4096 ? '✓' : '未達成'}',
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onVerticalDragEnd: _handleSwipe,
                  onHorizontalDragEnd: _handleHorizontalSwipe,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
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
                const Text('滑動棋盤進行生命合成'),
              ],
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
