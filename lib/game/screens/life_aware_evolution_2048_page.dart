import 'dart:async';

import 'package:flutter/material.dart';

import '../services/save_manager.dart';
import '../services/life_manager.dart';
import 'evolution_2048_page.dart';

/// Wraps the gameplay page with the persistent life system.
///
/// One normal life is consumed when a gameplay session starts. Golden members
/// have infinite lives and therefore never consume a life or show a timer.
class LifeAwareEvolution2048Page extends StatefulWidget {
  const LifeAwareEvolution2048Page({super.key});

  @override
  State<LifeAwareEvolution2048Page> createState() =>
      _LifeAwareEvolution2048PageState();
}

class _LifeAwareEvolution2048PageState
    extends State<LifeAwareEvolution2048Page> {
  Timer? _timer;
  bool _ready = false;
  bool _hasLife = true;
  int _lifeCount = LifeManager.normalCap;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await LifeManager.initialize();

    final saved = SaveManager.loadCached();
    final hasActiveSavedGame =
        saved != null &&
        saved['tiles'] is List &&
        saved['gameOver'] != true &&
        saved['chapterComplete'] != true;
    final allowed = hasActiveSavedGame
        ? LifeManager.lifeCount > 0
        : await LifeManager.consumeLife();
    if (!mounted) {
      return;
    }

    setState(() {
      _ready = true;
      _hasLife = allowed;
      _syncLifeState();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(_syncLifeState);
    });
  }

  void _syncLifeState() {
    if (LifeManager.isGoldenMember) {
      _lifeCount = -1;
      _remaining = null;
      _hasLife = true;
      return;
    }

    _lifeCount = LifeManager.lifeCount;
    _remaining = LifeManager.regenerationRemaining;
    _hasLife = _lifeCount > 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration? duration) {
    if (duration == null) {
      return '--:--';
    }

    final totalSeconds = duration.inSeconds.clamp(0, 5999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildLifeIndicator() {
    final text = LifeManager.isGoldenMember ? '生命 ♥ ∞' : '生命 ♥ $_lifeCount';
    final timerText = LifeManager.isGoldenMember
        ? ''
        : '⏱ ${_formatRemaining(_remaining)}';

    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (timerText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                timerText,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoLifeOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(28),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_border,
                  size: 52,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  '生命不足',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '下一點生命將在 ${_formatRemaining(_remaining)} 後恢復。',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        const Evolution2048Page(),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 62,
          left: 16,
          child: _buildLifeIndicator(),
        ),
        if (!_hasLife) _buildNoLifeOverlay(),
      ],
    );
  }
}
