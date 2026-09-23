    _completionAnimationPlaying = false;
    _completionAnimationIndex = null;
    _completionAnimationImagePath = null;
    if (result == 'home') {
      Navigator.of(context).pop();
      return;
    }
    if (result != 'next') {
      _focusNode.requestFocus();
      return;
    }
    switch (completedChapter) {
      case GameChapter.ocean: _startChapter(GameChapter.land, forceNewBoard: true); break;
      case GameChapter.land: _startChapter(GameChapter.sky, forceNewBoard: true); break;
      case GameChapter.sky: _startChapter(GameChapter.history, forceNewBoard: true); break;
      case GameChapter.history: _startChapter(GameChapter.tech, forceNewBoard: true); break;
      case GameChapter.tech: _startChapter(GameChapter.universe, forceNewBoard: true); break;
      case GameChapter.universe: _focusNode.requestFocus(); break;
    }
  }

  Future<void> _startChapter(
    GameChapter chapter, {
    bool forceNewBoard = false,
  }) async {
    if (!mounted) return;

    final started = await PlayerProgressService.instance.restartGameSession(
      chapter.index,
    );
    if (!started || !mounted) return;

    final newEngine = GameEngine(
      chapter: chapter,
      forceNewBoard: forceNewBoard,
    );
    newEngine.markBoardLifeActiveAfterServerRestart();

    setState(() {
      _engine = newEngine;
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
    // restartGameSession already returns the authoritative Life state, and
    // tool inventory is cached from the current account session. Do not add
    // another network round trip to the chapter transition.
    unawaited(AudioManager.instance.playChapterMusic(chapter));
    _focusNode.requestFocus();
  }

  String _toolLabel(GameToolType type) => switch (type) {
    GameToolType.revive => 'REMOVE',
    GameToolType.timeRewind => 'UNDO',
    GameToolType.positionSwap => 'SWAP',