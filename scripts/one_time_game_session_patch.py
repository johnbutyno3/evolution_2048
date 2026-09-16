from pathlib import Path


def replace_once(path: Path, old: str, new: str, marker: str) -> None:
    text = path.read_text(encoding='utf-8-sig')
    if old not in text:
        raise SystemExit(f'{marker}: marker not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


replay = Path('lib/game/services/replay_log.dart')
replace_once(
    replay,
    """  Map<String, dynamic> toJson() => <String, dynamic>{\n        'replayVersion': currentVersion,\n""",
    """  Map<String, dynamic> toJson() => <String, dynamic>{\n        'version': currentVersion,\n        'replayVersion': currentVersion,\n""",
    'ReplayLog toJson',
)
replace_once(
    replay,
    """    final version = raw['replayVersion'];\n""",
    """    final version = raw['version'] ?? raw['replayVersion'];\n""",
    'ReplayLog version parser',
)

page = Path('lib/game/screens/evolution_2048_page.dart')
replace_once(
    page,
    """  Timer? _uiRefreshTimer;\n\n  static const double _swipeThreshold = 30;\n""",
    """  Timer? _uiRefreshTimer;\n  bool _gameSessionStarting = false;\n\n  static const double _swipeThreshold = 30;\n""",
    'Session state',
)
replace_once(
    page,
    """      _resumeGameplay();\n      unawaited(\n        _engine.refreshToolProgress().then((_) {\n""",
    """      _resumeGameplay();\n      PlayerProgressService.instance.clearGameSession();\n      if (!_engine.gameOver && !_engine.chapterComplete) {\n        unawaited(_ensureGameSession());\n      }\n      unawaited(\n        _engine.refreshToolProgress().then((_) {\n""",
    'Session startup',
)
replace_once(
    page,
    """  void _startUiRefreshTimer() {\n""",
    """  Future<bool> _ensureGameSession() async {\n    if (_gameSessionStarting) {\n      while (_gameSessionStarting) {\n        await Future<void>.delayed(const Duration(milliseconds: 20));\n      }\n      return PlayerProgressService.instance.activeGameSessionId != null;\n    }\n\n    if (PlayerProgressService.instance.activeGameSessionId != null) {\n      return true;\n    }\n\n    _gameSessionStarting = true;\n    try {\n      return await PlayerProgressService.instance.startGameSession(\n        _chapterNumber - 1,\n      );\n    } finally {\n      _gameSessionStarting = false;\n    }\n  }\n\n  void _startUiRefreshTimer() {\n""",
    'Session helper',
)
replace_once(
    page,
    """    if (!restarted) {\n      return false;\n    }\n\n    _engine.startGameTimer();\n""",
    """    if (!restarted) {\n      return false;\n    }\n\n    PlayerProgressService.instance.clearGameSession();\n    unawaited(_ensureGameSession());\n\n    _engine.startGameTimer();\n""",
    'Restart session',
)
replace_once(
    page,
    """    } else {\n      Navigator.of(context).pop();\n    }\n  }\n\n  // ============================================================\n  // Background\n""",
    """    } else {\n      PlayerProgressService.instance.clearGameSession();\n      Navigator.of(context).pop();\n    }\n  }\n\n  // ============================================================\n  // Background\n""",
    'Game over session clear',
)
replace_once(
    page,
    """    _chapterCompleteShowing = true;\n    _engine.stopGameTimer();\n\n    final completedChapter = _engine.chapter;\n""",
    """    _chapterCompleteShowing = true;\n    _engine.stopGameTimer();\n\n    if (!await _ensureGameSession()) {\n      _chapterCompleteShowing = false;\n      return;\n    }\n\n    final completedChapter = _engine.chapter;\n""",
    'Completion session',
)
replace_once(
    page,
    """    await PlayerProgressService.instance.completeChapter(\n      chapterIndex: _chapterNumber - 1,\n      replayLog: Map<String, dynamic>.from(replayLog),\n    );\n\n    await AudioManager.instance.stopMusic();\n""",
    """    final completionAccepted =\n        await PlayerProgressService.instance.completeChapter(\n          chapterIndex: _chapterNumber - 1,\n          replayLog: Map<String, dynamic>.from(replayLog),\n        );\n\n    if (!completionAccepted) {\n      _chapterCompleteShowing = false;\n      return;\n    }\n\n    await AudioManager.instance.stopMusic();\n""",
    'Completion result',
)
replace_once(
    page,
    """    setState(() {\n      _engine = GameEngine(chapter: chapter, forceNewBoard: forceNewBoard);\n\n      _toolMode = null;\n""",
    """    PlayerProgressService.instance.clearGameSession();\n\n    setState(() {\n      _engine = GameEngine(chapter: chapter, forceNewBoard: forceNewBoard);\n\n      _toolMode = null;\n""",
    'Chapter transition session',
)
replace_once(
    page,
    """    _engine.updateLifeFromRealTime();\n    _engine.startGameTimer();\n    _startUiRefreshTimer();\n\n    AudioManager.instance.playChapterMusic(chapter);\n""",
    """    _engine.updateLifeFromRealTime();\n    _engine.startGameTimer();\n    _startUiRefreshTimer();\n    unawaited(_ensureGameSession());\n\n    AudioManager.instance.playChapterMusic(chapter);\n""",
    'Chapter session startup',
)
