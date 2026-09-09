import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/life_manager.dart';
import '../services/save_manager.dart';
import 'evolution_2048_page.dart';

/// Wraps the gameplay page with the persistent life system.
///
/// A life is consumed only when a brand-new gameplay attempt is started.
/// Existing saved games, Game Over states, and completed chapters never
/// consume another life merely by opening the page.
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

    // The first actual game start consumes one life. Once a save exists,
    // reopening the app resumes that state without consuming another life.
    final saved = SaveManager.loadCached();
    final hasSavedGame = saved != null &&
        saved['tiles'] is List &&
        (saved['tiles'] as List).length == 16;

    final allowed = hasSavedGame
        ? LifeManager.lifeCount > 0 ||
            saved['gameOver'] == true ||
            saved['chapterComplete'] == true
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

    // A saved Game Over/completed chapter can still be displayed even when
    // no life remains; the next explicit new game/restart is responsible for
    // checking whether a life can be consumed.
    _hasLife = _lifeCount > 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(Duration? duration) {
    if (duration == null) {
      return '';
    }

    final totalSeconds = duration.inSeconds.clamp(0, 5999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildLifeIndicator() {
    final l10n = AppLocalizations.of(context)!;
    final text = LifeManager.isGoldenMember
        ? '${l10n.life} ♥ ∞'
        : '${l10n.life} ♥ $_lifeCount';

    final timerText = _lifeCount < LifeManager.normalCap
        ? _formatRemaining(_remaining)
        : '';

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
    final l10n = AppLocalizations.of(context)!;

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
                Text(
                  l10n.life,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatRemaining(_remaining)}',
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
