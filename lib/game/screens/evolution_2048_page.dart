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

    if (_engine.hasReached4096) {
      _showMilestone('4096', '海底人類');
    } else if (_engine.hasReached2048) {
      _showMilestone('2048', '藍鯨');
    } else if (_engine.gameOver) {
      _showGameOver();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (details.primaryVelocity == null) return;

    final direction = velocity.abs() < 50
        ? null
        : velocity < 0
            ? 'up'
            : 'down';

    if (direction != null) {
      _move(direction);
    }
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 50) return;
    _move(velocity < 0 ? 'left' : 'right');
  }

  void _reset() {
    setState(_engine.reset);
  }

  void _showMilestone(String value, String name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(value),
          content: Text('$name 已誕生'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('繼續'),
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
        title: const Text('Rebirth 2048'),
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
                const Text(
                  'Chapter 1 · Ocean',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        final tile = _engine.board.tiles[index];
                        return _TileView(tile: tile);
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
